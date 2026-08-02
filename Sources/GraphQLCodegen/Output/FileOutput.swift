import Foundation

actor FileOutput {
    @TaskLocal static var current: FileOutput?

    static var required: FileOutput {
        guard let current else {
            preconditionFailure("FileOutput must be scoped to a Codegen run")
        }
        return current
    }

    private struct StagedFile {
        let temporaryURL: URL
        let finalURL: URL
        let restoreOnDiscard: Bool
    }

    private struct Backup {
        let temporaryURL: URL
        let originalURL: URL
    }

    private let temporaryDirectory = FileManager.default.temporaryDirectory
    private var directoriesToCreate: Set<URL> = []
    private var urlsToRemove: Set<URL> = []
    private var urlsToSave: Set<URL> = []
    private var stagedFiles: [StagedFile] = []

    func createDirectory(at destination: URL) {
        directoriesToCreate.insert(destination)
    }

    func remove(at url: URL) {
        urlsToRemove.insert(url)
    }

    func remove(at urls: any Sequence<URL>) {
        urlsToRemove.formUnion(urls)
    }

    func save(at url: URL) {
        urlsToSave.insert(url)
    }

    func write(_ lines: [String], to url: URL) throws {
        let tempURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: tempURL.path(percentEncoded: false), contents: nil)
        let handle = try FileHandle(forWritingTo: tempURL)
        let bufferSize = 4 * 1024
        var buffer: [UInt8] = []
        buffer.reserveCapacity(bufferSize)
        let newlineData = "\n".utf8
        for line in lines {
            buffer.append(contentsOf: line.utf8)
            buffer.append(contentsOf: newlineData)
            if buffer.count >= bufferSize {
                try handle.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
            }
        }
        try handle.write(contentsOf: buffer)
        try handle.close()
        stagedFiles.append(StagedFile(temporaryURL: tempURL, finalURL: url, restoreOnDiscard: false))
    }

    func write(_ data: Data, to url: URL) throws {
        let tempURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: tempURL.path(percentEncoded: false), contents: data)
        stagedFiles.append(StagedFile(temporaryURL: tempURL, finalURL: url, restoreOnDiscard: false))
    }

    func execute() throws {
        var backups: [Backup] = []
        var published: [StagedFile] = []
        var createdDirectories: [URL] = []
        do {
            try urlsToSave.sorted(by: pathOrder).forEach { url in
                let tempURL = temporaryURL()
                try FileManager.default.moveItem(at: url, to: tempURL)
                stagedFiles.append(StagedFile(temporaryURL: tempURL, finalURL: url, restoreOnDiscard: true))
            }
            urlsToSave.removeAll()

            let removalRoots = minimalRemovalRoots()
            for url in removalRoots where fileExists(at: url) {
                let backup = Backup(temporaryURL: temporaryURL(), originalURL: url)
                try FileManager.default.moveItem(at: url, to: backup.temporaryURL)
                backups.append(backup)
            }

            for stagedFile in stagedFiles where fileExists(at: stagedFile.finalURL) &&
                !removalRoots.contains(where: { contains($0, stagedFile.finalURL) }) {
                let backup = Backup(temporaryURL: temporaryURL(), originalURL: stagedFile.finalURL)
                try FileManager.default.moveItem(at: stagedFile.finalURL, to: backup.temporaryURL)
                backups.append(backup)
            }

            for directory in directoriesToCreate.sorted(by: pathOrder) {
                if !fileExists(at: directory) {
                    createdDirectories.append(directory)
                }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            for stagedFile in stagedFiles {
                let parent = stagedFile.finalURL.deletingLastPathComponent()
                if !fileExists(at: parent) {
                    createdDirectories.append(parent)
                    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
                }
                try FileManager.default.moveItem(at: stagedFile.temporaryURL, to: stagedFile.finalURL)
                published.append(stagedFile)
            }

            for backup in backups {
                try? FileManager.default.removeItem(at: backup.temporaryURL)
            }
            reset()
        } catch {
            rollback(published: published, backups: backups, createdDirectories: createdDirectories)
            throw error
        }
    }

    func discard() {
        for stagedFile in stagedFiles where FileManager.default.fileExists(
            atPath: stagedFile.temporaryURL.path(percentEncoded: false)
        ) {
            if stagedFile.restoreOnDiscard,
               !FileManager.default.fileExists(atPath: stagedFile.finalURL.path(percentEncoded: false)) {
                try? FileManager.default.createDirectory(
                    at: stagedFile.finalURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try? FileManager.default.moveItem(at: stagedFile.temporaryURL, to: stagedFile.finalURL)
            } else {
                try? FileManager.default.removeItem(at: stagedFile.temporaryURL)
            }
        }
        reset()
    }

    private func rollback(published: [StagedFile], backups: [Backup], createdDirectories: [URL]) {
        for stagedFile in published.reversed() where fileExists(at: stagedFile.finalURL) {
            if stagedFile.restoreOnDiscard {
                try? FileManager.default.moveItem(at: stagedFile.finalURL, to: stagedFile.temporaryURL)
            } else {
                try? FileManager.default.removeItem(at: stagedFile.finalURL)
            }
        }
        for directory in createdDirectories.sorted(by: pathOrder).reversed() where fileExists(at: directory) {
            try? FileManager.default.removeItem(at: directory)
        }
        for backup in backups.reversed() {
            if fileExists(at: backup.originalURL) {
                try? FileManager.default.removeItem(at: backup.originalURL)
            }
            try? FileManager.default.createDirectory(
                at: backup.originalURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? FileManager.default.moveItem(at: backup.temporaryURL, to: backup.originalURL)
        }
        discard()
    }

    private func minimalRemovalRoots() -> [URL] {
        urlsToRemove
            .filter { candidate in
                !urlsToRemove.contains { other in other != candidate && contains(other, candidate) }
            }
            .sorted(by: pathOrder)
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

    private func reset() {
        directoriesToCreate.removeAll()
        urlsToRemove.removeAll()
        urlsToSave.removeAll()
        stagedFiles.removeAll()
    }
}

extension String {
    func write(to url: URL) async throws {
        try await FileOutput.required.write(Data(utf8), to: url)
    }
}
