import Foundation

actor FileOutput {
    static let `default` = FileOutput()

    private struct StagedFile {
        let temporaryURL: URL
        let finalURL: URL
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
        stagedFiles.append(StagedFile(temporaryURL: tempURL, finalURL: url))
    }

    func write(_ data: Data, to url: URL) throws {
        let tempURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: tempURL.path(percentEncoded: false), contents: data)
        stagedFiles.append(StagedFile(temporaryURL: tempURL, finalURL: url))
    }

    func execute() throws {
        try urlsToSave.forEach { url in
            let tempURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.moveItem(at: url, to: tempURL)
            stagedFiles.append(StagedFile(temporaryURL: tempURL, finalURL: url))
        }
        urlsToSave.removeAll()

        try urlsToRemove.forEach { url in
            if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                try FileManager.default.removeItem(at: url)
            }
        }
        urlsToRemove.removeAll()

        try directoriesToCreate.forEach { directory in
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        directoriesToCreate.removeAll()

        try stagedFiles.forEach { stagedFile in
            if FileManager.default.fileExists(atPath: stagedFile.finalURL.path(percentEncoded: false)) {
                try FileManager.default.removeItem(at: stagedFile.finalURL)
            }
            try FileManager.default.moveItem(at: stagedFile.temporaryURL, to: stagedFile.finalURL)
        }
        stagedFiles.removeAll()
    }
}

extension String {
    func write(to url: URL) async throws {
        try await FileOutput.default.write(Data(utf8), to: url)
    }
}
