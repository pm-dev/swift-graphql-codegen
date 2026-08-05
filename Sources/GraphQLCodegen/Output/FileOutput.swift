import Foundation

actor FileOutput {
    struct TransactionError: Swift.Error, CustomStringConvertible {
        let description: String
    }

    private enum StagedFileKind {
        case generated
        case preserved
    }

    private struct StagedFile {
        let temporaryURL: URL
        let finalURL: URL
        let kind: StagedFileKind
    }

    private struct Backup {
        let temporaryURL: URL
        let originalURL: URL
    }

    private struct CommitState {
        var backups: [Backup] = []
        var createdDirectories: [URL] = []
        var published: [StagedFile] = []
    }

    private enum State {
        case staging
        case recoveryRequired
        case finished
    }

    private let temporaryDirectory = FileManager.default.temporaryDirectory
    private var directoriesToCreate: Set<URL> = []
    private var urlsToRemove: Set<URL> = []
    private var urlsToSave: Set<URL> = []
    private var stagedFiles: [StagedFile] = []
    private var state = State.staging

    func createDirectory(at destination: URL) {
        requireStaging()
        directoriesToCreate.insert(destination)
    }

    func remove(at url: URL) {
        requireStaging()
        urlsToRemove.insert(url)
    }

    func remove(at urls: any Sequence<URL>) {
        requireStaging()
        urlsToRemove.formUnion(urls)
    }

    func save(at url: URL) {
        requireStaging()
        urlsToSave.insert(url)
    }

    func write(_ lines: [String], to url: URL) throws {
        let contents = lines.joined(separator: "\n") + "\n"
        try write(Data(contents.utf8), to: url)
    }

    func write(_ data: Data, to url: URL) throws {
        requireStaging()
        let tempURL = temporaryURL()
        try data.write(to: tempURL)
        stagedFiles.append(StagedFile(temporaryURL: tempURL, finalURL: url, kind: .generated))
    }

    func execute() throws {
        requireStaging()
        var commitState = CommitState()
        do {
            try urlsToSave.sorted(by: pathOrder).forEach { url in
                let tempURL = temporaryURL()
                try FileManager.default.moveItem(at: url, to: tempURL)
                stagedFiles.append(StagedFile(temporaryURL: tempURL, finalURL: url, kind: .preserved))
            }
            urlsToSave.removeAll()

            let removalRoots = minimalRemovalRoots()
            for url in removalRoots where fileExists(at: url) {
                let backup = Backup(temporaryURL: temporaryURL(), originalURL: url)
                try FileManager.default.moveItem(at: url, to: backup.temporaryURL)
                commitState.backups.append(backup)
            }

            for stagedFile in stagedFiles where fileExists(at: stagedFile.finalURL) &&
                !removalRoots.contains(where: { contains($0, stagedFile.finalURL) }) {
                let backup = Backup(temporaryURL: temporaryURL(), originalURL: stagedFile.finalURL)
                try FileManager.default.moveItem(at: stagedFile.finalURL, to: backup.temporaryURL)
                commitState.backups.append(backup)
            }

            for directory in directoriesToCreate.sorted(by: pathOrder) {
                if !fileExists(at: directory) {
                    commitState.createdDirectories.append(directory)
                }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            for stagedFile in stagedFiles {
                let parent = stagedFile.finalURL.deletingLastPathComponent()
                if !fileExists(at: parent) {
                    commitState.createdDirectories.append(parent)
                    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
                }
                try FileManager.default.moveItem(at: stagedFile.temporaryURL, to: stagedFile.finalURL)
                commitState.published.append(stagedFile)
            }

            removeCommittedBackups(commitState.backups)
            finish()
        } catch {
            let commitError = error
            let recoveryFailures = rollback(commitState)
            if recoveryFailures.isEmpty {
                finish()
                throw commitError
            }
            state = .recoveryRequired
            throw TransactionError(description: """
            Failed to commit generated output: \(commitError)
            Automatic recovery was incomplete. Recovery files were retained in the temporary directory.
            \(recoveryFailures.joined(separator: "\n"))
            """)
        }
    }

    func discard() throws {
        requireStaging()
        var failures: [String] = []
        for stagedFile in stagedFiles where fileExists(at: stagedFile.temporaryURL) {
            if let failure = recoveryFailure(
                "Failed to remove staged file \(stagedFile.temporaryURL.path)",
                operation: { try FileManager.default.removeItem(at: stagedFile.temporaryURL) }
            ) {
                failures.append(failure)
            }
        }
        guard failures.isEmpty else {
            throw TransactionError(description: """
            Failed to discard staged generated output. The files were retained for recovery.
            \(failures.joined(separator: "\n"))
            """)
        }
        finish()
    }

    private func rollback(_ commitState: CommitState) -> [String] {
        var failures: [String] = []
        for stagedFile in commitState.published.reversed() where fileExists(at: stagedFile.finalURL) {
            let failure = switch stagedFile.kind {
            case .generated:
                recoveryFailure(
                    "Failed to remove published file \(stagedFile.finalURL.path)",
                    operation: { try FileManager.default.removeItem(at: stagedFile.finalURL) }
                )
            case .preserved:
                recoveryFailure(
                    "Failed to stage preserved file \(stagedFile.finalURL.path) for restoration at " +
                        stagedFile.temporaryURL.path,
                    operation: {
                        try FileManager.default.moveItem(
                            at: stagedFile.finalURL,
                            to: stagedFile.temporaryURL
                        )
                    }
                )
            }
            if let failure {
                failures.append(failure)
            }
        }

        for directory in commitState.createdDirectories.sorted(by: pathOrder).reversed()
        where fileExists(at: directory) {
            if let failure = recoveryFailure(
                "Failed to remove created directory \(directory.path)",
                operation: { try FileManager.default.removeItem(at: directory) }
            ) {
                failures.append(failure)
            }
        }

        for backup in commitState.backups.reversed() {
            if fileExists(at: backup.originalURL),
               let failure = recoveryFailure(
                   "Failed to clear \(backup.originalURL.path) before restoring " + backup.temporaryURL.path,
                   operation: { try FileManager.default.removeItem(at: backup.originalURL) }
               ) {
                failures.append(failure)
            }
            if !fileExists(at: backup.originalURL) {
                if let failure = recoveryFailure(
                    "Failed to create the parent directory for \(backup.originalURL.path)",
                    operation: {
                        try FileManager.default.createDirectory(
                            at: backup.originalURL.deletingLastPathComponent(),
                            withIntermediateDirectories: true
                        )
                    }
                ) {
                    failures.append(failure)
                }
                if let failure = recoveryFailure(
                    "Failed to restore \(backup.originalURL.path) from \(backup.temporaryURL.path)",
                    operation: {
                        try FileManager.default.moveItem(
                            at: backup.temporaryURL,
                            to: backup.originalURL
                        )
                    }
                ) {
                    failures.append(failure)
                }
            }
        }

        for stagedFile in stagedFiles where fileExists(at: stagedFile.temporaryURL) {
            let failure = switch stagedFile.kind {
            case .generated:
                recoveryFailure(
                    "Failed to remove staged file \(stagedFile.temporaryURL.path)",
                    operation: { try FileManager.default.removeItem(at: stagedFile.temporaryURL) }
                )
            case .preserved:
                recoveryFailure(
                    "Failed to restore preserved file \(stagedFile.finalURL.path) from " +
                        stagedFile.temporaryURL.path,
                    operation: {
                        try FileManager.default.createDirectory(
                            at: stagedFile.finalURL.deletingLastPathComponent(),
                            withIntermediateDirectories: true
                        )
                        try FileManager.default.moveItem(
                            at: stagedFile.temporaryURL,
                            to: stagedFile.finalURL
                        )
                    }
                )
            }
            if let failure {
                failures.append(failure)
            }
        }
        return failures
    }

    private func removeCommittedBackups(_ backups: [Backup]) {
        for backup in backups {
            do {
                try FileManager.default.removeItem(at: backup.temporaryURL)
            } catch {
                // Output is fully committed at this point. Removing a redundant backup is cleanup,
                // so preserve the successful generation result and make the retained file visible.
                print("Warning: retained output backup at \(backup.temporaryURL.path): \(error)")
            }
        }
    }

    private func recoveryFailure(
        _ context: String,
        operation: () throws -> Void
    ) -> String? {
        do {
            try operation()
            return nil
        } catch {
            return "\(context): \(error)"
        }
    }

    private func minimalRemovalRoots() -> [URL] {
        let candidates = urlsToRemove
            .map { url in
                (url: url, components: url.standardizedFileURL.pathComponents)
            }
            .sorted { lhs, rhs in
                lhs.components.lexicographicallyPrecedes(rhs.components)
            }
        var roots: [(url: URL, components: [String])] = []
        for candidate in candidates {
            if let currentRoot = roots.last,
               candidate.components.starts(with: currentRoot.components) {
                continue
            }
            roots.append(candidate)
        }
        return roots.map(\.url).sorted(by: pathOrder)
    }

    private func contains(_ parent: URL, _ child: URL) -> Bool {
        let parentComponents = parent.standardizedFileURL.pathComponents
        let childComponents = child.standardizedFileURL.pathComponents
        return childComponents.starts(with: parentComponents)
    }

    private func pathOrder(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.path < rhs.path
    }

    private func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    private func temporaryURL() -> URL {
        temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    private func requireStaging() {
        guard case .staging = state else {
            preconditionFailure("FileOutput can only stage changes before commit or discard")
        }
    }

    private func finish() {
        directoriesToCreate.removeAll()
        urlsToRemove.removeAll()
        urlsToSave.removeAll()
        stagedFiles.removeAll()
        state = .finished
    }
}

extension String {
    func write(to url: URL, using fileOutput: FileOutput) async throws {
        try await fileOutput.write(Data(utf8), to: url)
    }
}
