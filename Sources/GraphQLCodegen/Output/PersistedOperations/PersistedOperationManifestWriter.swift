import Foundation

struct PersistedOperationManifestWriter {
    let manifestURL: URL
    let operations: [PersistedOperationManifest.Operation]

    func write(using fileOutput: FileOutput) throws {
        let manifest = PersistedOperationManifest(operations: operations)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try fileOutput.write(data, to: manifestURL)
    }
}
