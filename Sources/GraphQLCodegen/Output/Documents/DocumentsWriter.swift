import Foundation

struct DocumentsWriter {
    enum DefinitionPlan {
        case fragment(
            ResolvedFragment,
            includesSelectionSet: Bool,
            declaration: GeneratedTypeDeclaration
        )
        case operation(ResolvedOperation, GeneratedTypeDeclaration)

        var declaration: GeneratedTypeDeclaration {
            switch self {
            case .fragment(_, _, let declaration), .operation(_, let declaration): declaration
            }
        }
    }

    struct DocumentPlan {
        let document: Document
        let definitions: [DefinitionPlan]
    }

    private enum GeneratedFileFinderError: Error {
        case failedToEnumerateDirectory(URL)
    }

    let configuration: Configuration
    let documentPlans: [DocumentPlan]

    var topLevelDeclarations: [GeneratedTypeDeclaration] {
        documentPlans.flatMap(\.definitions).map(\.declaration)
    }

    init(configuration: Configuration, resolvedDocuments: ResolvedDocuments) throws {
        var documentPlans: [DocumentPlan] = []
        for resolvedDocument in resolvedDocuments.documents {
            var definitions: [DefinitionPlan] = []
            for definition in resolvedDocument.resolvedDefinitions {
                switch definition {
                case .operation(let operation):
                    let declaration = try GeneratedTypeDeclaration(
                        name: SwiftTypeIdentifier(
                            operation: operation.operation,
                            in: resolvedDocument.document
                        ),
                        origin: .operation(
                            name: operation.operation.ast.name?.value,
                            file: resolvedDocument.document.url
                        )
                    )
                    definitions.append(.operation(operation, declaration))
                case .fragment(let name):
                    guard let fragment = resolvedDocuments.fragmentLookup[name] else { continue }
                    let includesSelectionSet = resolvedDocuments.fulfilledFragments.contains(name)
                    let declaration = GeneratedTypeDeclaration(
                        name: SwiftTypeIdentifier(capitalizing: name),
                        origin: .fragment(name: name, file: fragment.fragment.file)
                    )
                    definitions.append(
                        .fragment(
                            fragment,
                            includesSelectionSet: includesSelectionSet,
                            declaration: declaration
                        )
                    )
                }
            }
            documentPlans.append(
                DocumentPlan(document: resolvedDocument.document, definitions: definitions)
            )
        }
        self.configuration = configuration
        self.documentPlans = documentPlans
    }

    func write(using fileOutput: FileOutput) throws {
        try validateOutputURLs()
        if case .directory(let url) = configuration.output.documents.directory {
            fileOutput.createDirectory(at: url)
        }
        for plannedDocument in documentPlans {
            let document = plannedDocument.document
            var file = SwiftFileWriter()
            file.setHeader(configuration.output.documents.header)
            file.setImports(configuration.output.documents.importedModules)
            for definition in plannedDocument.definitions {
                switch definition {
                case .operation(let resolvedOperation, let declaration):
                    let operation = try buildOperation(
                        resolvedOperation,
                        typeName: declaration.name,
                        in: document
                    )
                    file.addType(operation)
                case .fragment(
                    let resolvedFragment,
                    let includesSelectionSet,
                    let declaration
                ):
                    try file.addType(
                        buildFragment(
                            resolvedFragment,
                            typeName: declaration.name,
                            includesSelectionSet: includesSelectionSet,
                            in: document
                        )
                    )
                }
            }
            try file.write(to: document.outputURL(configuration), configuration: configuration, using: fileOutput)
        }
        let generated = documentPlans.map { $0.document.outputURL(configuration) }
        let removed = try previouslyGeneratedFileURLs().subtracting(generated)
        fileOutput.remove(at: removed)
    }

    private func previouslyGeneratedFileURLs() throws -> Set<URL> {
        let directories: [URL]
        switch configuration.output.documents.directory {
        case .definition:
            directories = configuration.input.documentDirectories
        case .directory(let directory):
            directories = [directory]
        }
        return try Set(
            directories
                .sorted { $0.path < $1.path }
                .flatMap(generatedFileURLs(in:))
        )
    }

    private func generatedFileURLs(in directory: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else {
            return []
        }
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]
        guard let directoryEnumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: .skipsHiddenFiles
        )
        else {
            throw GeneratedFileFinderError.failedToEnumerateDirectory(directory)
        }
        var generatedFileURLs: [URL] = []
        for case let url as URL in directoryEnumerator
            where try url.resourceValues(forKeys: resourceKeys).isRegularFile == true &&
            url.lastPathComponent.hasSuffix(".graphql.swift") {
            generatedFileURLs.append(url)
        }
        return generatedFileURLs
    }

    private func validateOutputURLs() throws {
        var sourceByOutputURL: [URL: URL] = [:]
        for plannedDocument in documentPlans {
            let document = plannedDocument.document
            let outputURL = document.outputURL(configuration).standardizedFileURL
            if let existingSource = sourceByOutputURL[outputURL] {
                throw Codegen.Error(description: """
                Multiple GraphQL documents resolve to the same generated output file:
                Output: \(outputURL)
                Sources:
                \(existingSource)
                \(document.url)
                """)
            }
            sourceByOutputURL[outputURL] = document.url
        }
    }

    private func buildOperation(
        _ operation: ResolvedOperation,
        typeName: SwiftTypeIdentifier,
        in document: Document
    ) throws -> SwiftTypeBuildable {
        let operation = OperationBuilder(
            configuration: configuration,
            document: document,
            resolvedOperation: operation,
            typeName: typeName
        )
        return try operation.buildable()
    }

    private func buildFragment(
        _ resolvedFragment: ResolvedFragment,
        typeName: SwiftTypeIdentifier,
        includesSelectionSet: Bool,
        in document: Document
    ) throws -> SwiftTypeBuildable {
        let fragment = FragmentBuilder(
            configuration: configuration,
            document: document,
            resolvedFragment: resolvedFragment,
            typeName: typeName,
            includesSelectionSet: includesSelectionSet
        )
        return try fragment.buildable()
    }
}
