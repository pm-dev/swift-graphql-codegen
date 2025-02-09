import Foundation

struct PersistedOperationManifestWriter {
    let manifestURL: URL
    let documents: Documents

    func write() async throws {
        var operations: [PersistedOperationManifest.Operation] = []
        for document in documents.documents {
            for definition in document.definitions {
                switch definition {
                case .operation(let operation):
                    operations.append(
                        PersistedOperationManifest.Operation(
                            id: operation.hash!,
                            body: operation.resolvedText!,
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
        try await FileOutput.default.write(data, to: manifestURL)
    }
}
