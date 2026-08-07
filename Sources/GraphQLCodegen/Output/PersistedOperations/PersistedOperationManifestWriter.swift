import Foundation

struct PersistedOperationManifestWriter {
    let manifestURL: URL
    let documents: Documents

    func write(using fileOutput: FileOutput) throws {
        var operations: [PersistedOperationManifest.Operation] = []
        for document in documents.documents {
            for definition in document.definitions {
                switch definition {
                case .operation(let operation):
                    switch operation.persistence {
                    case .registered(let hash):
                        operations.append(
                            PersistedOperationManifest.Operation(
                                id: hash,
                                body: operation.canonicalText,
                                name: operation.ast.name?.value,
                                type: operation.ast.operation.rawValue
                            )
                        )
                    case .standard:
                        preconditionFailure("A registered operation manifest requires registered operations")
                    }
                case .fragment: break
                }
            }
        }
        let manifest = PersistedOperationManifest(operations: operations)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try fileOutput.write(data, to: manifestURL)
    }
}
