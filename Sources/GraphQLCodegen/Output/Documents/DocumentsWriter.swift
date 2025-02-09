import Foundation
import OrderedCollections

struct DocumentsWriter {
    let configuration: Configuration
    let resolvedDocuments: ResolvedDocuments

    func write() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for resolvedDocument in resolvedDocuments.documents {
                group.addTask {
                    let document = resolvedDocument.document
                    var file = SwiftFileWriter()
                    file.setHeader(configuration.output.documents.header)
                    file.setImports(configuration.output.documents.importedModules)
                    var emptyFile = true
                    for definition in resolvedDocument.resolvedDefinitions {
                        switch definition {
                        case .operation(let resolvedOperation):
                            let operation = try buildOperation(resolvedOperation, in: document)
                            file.addType(operation)
                            emptyFile = false
                        case .fragment(let name):
                            if let fragment = try buildFragment(name, in: document) {
                                file.addType(fragment)
                                emptyFile = false
                            }
                        }
                    }
                    if emptyFile {
                        await FileOutput.default.remove(at: document.generatedSwiftFile)
                    } else {
                        try await file.write(to: document.generatedSwiftFile, configuration: configuration)
                    }
                }
                try await group.waitForAll()
            }
        }
        let generated = resolvedDocuments.documents.map(\.document.generatedSwiftFile)
        let removed = Set(resolvedDocuments.previouslyGenerated).subtracting(generated)
        await FileOutput.default.remove(at: removed)
    }

    private func buildOperation(
        _ operation: ResolvedOperation,
        in document: Document
    ) throws -> SwiftTypeBuildable {
        var operation = OperationBuilder(
            configuration: configuration,
            document: document,
            resolvedOperation: operation,
            resolvedDocuments: resolvedDocuments
        )
        return try operation.buildable()
    }

    private func buildFragment(
        _ fragmentName: String,
        in document: Document
    ) throws -> SwiftTypeBuildable? {
        guard let resolvedFragment = resolvedDocuments.fragmentLookup[fragmentName] else {
            return nil // fragment not used
        }
        var fragment = FragmentBuilder(
            configuration: configuration,
            document: document,
            resolvedFragment: resolvedFragment,
            resolvedDocuments: resolvedDocuments
        )
        return try fragment.buildable()
    }
}
