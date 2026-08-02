import Foundation
import OrderedCollections

struct DocumentsWriter {
    let configuration: Configuration
    let resolvedDocuments: ResolvedDocuments

    func write(using fileOutput: FileOutput) async throws {
        switch configuration.output.documents.directory {
        case .definition: break
        case .directory(let url):
            await fileOutput.createDirectory(at: url)
        }
        for resolvedDocument in resolvedDocuments.documents {
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
            let outputURL = document.outputURL(configuration)
            if emptyFile {
                await fileOutput.remove(at: outputURL)
            } else {
                try await file.write(to: outputURL, configuration: configuration, using: fileOutput)
            }
        }
        let generated = resolvedDocuments.documents.map { $0.document.outputURL(configuration) }
        let removed = Set(resolvedDocuments.previouslyGenerated).subtracting(generated)
        await fileOutput.remove(at: removed)
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
