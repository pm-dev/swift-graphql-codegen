import Foundation

struct PersistedOperationManifestWriter {
    let manifestURL: URL
    let documents: Documents

    func write(using fileOutput: FileOutput) async throws {
        var operations: [PersistedOperationManifest.Operation] = []
        for document in documents.documents {
            for definition in document.definitions {
                switch definition {
                case .operation(let operation):
                    operations.append(
                        PersistedOperationManifest.Operation(
                            id: operation.canonicalHash,
                            body: operation.canonicalText,
                            name: operation.ast.name?.value,
                            type: operation.ast.operation.rawValue
                        )
                    )
                case .fragment: break
                }
            }
        }
        let manifest = PersistedOperationManifest(operations: operations)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try await fileOutput.write(data, to: manifestURL)
    }
}
