import Foundation
import OrderedCollections

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

    let configuration: Configuration
    let documentPlans: [DocumentPlan]

    private let previouslyGenerated: [URL]

    init(configuration: Configuration, resolvedDocuments: ResolvedDocuments) throws {
        var documentPlans: [DocumentPlan] = []
        for resolvedDocument in resolvedDocuments.documents {
            var definitions: [DefinitionPlan] = []
            for definition in resolvedDocument.resolvedDefinitions {
                switch definition {
                case .operation(let operation):
                    let declaration = GeneratedTypeDeclaration(
                        name: try SwiftTypeIdentifier(
                            operation: operation.operation,
                            in: resolvedDocument.document
                        ),
                        origin: .operation(
                            name: operation.operation.ast.name?.value,
                            file: resolvedDocument.document.url
                        ),
                        conformances: configuration.operationConformances(
                            for: operation.operation.ast.operation
                        )
                    )
                    definitions.append(.operation(operation, declaration))
                case .fragment(let name):
                    guard let fragment = resolvedDocuments.fragmentLookup[name] else { continue }
                    let includesSelectionSet = resolvedDocuments.fulfilledFragments.contains(name)
                    let declaration = GeneratedTypeDeclaration(
                        name: SwiftTypeIdentifier(capitalizing: name),
                        origin: .fragment(name: name, file: fragment.fragment.file),
                        conformances: includesSelectionSet ?
                            configuration.output.documents.fragments.conformances : []
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
        self.previouslyGenerated = resolvedDocuments.previouslyGenerated
    }

    var topLevelDeclarations: [GeneratedTypeDeclaration] {
        documentPlans.flatMap(\.definitions).map(\.declaration)
    }

    var conformanceTypeReferences: Set<SwiftTypeIdentifier> {
        Set(plannedConformances.compactMap { conformance in
            let conformance = SwiftConformanceName(source: conformance)
            guard conformance.standardLibraryReference == nil else { return nil }
            return conformance.lookupTypeName
        })
    }

    var moduleQualifiers: Set<SwiftTypeIdentifier> {
        Set(plannedConformances.compactMap { conformance in
            SwiftConformanceName(source: conformance).moduleQualifier
        }).union([.swiftModule])
    }

    private var plannedConformances: [String] {
        documentPlans.flatMap { documentPlan in
            documentPlan.definitions.flatMap { definition in
                var conformances = definition.declaration.conformances
                switch definition {
                case .fragment:
                    break
                case .operation(let operation, _):
                    conformances += configuration.output.documents.operations.responseData.conformances
                    if !operation.operation.ast.variableDefinitions.isEmpty {
                        conformances += configuration.output.documents.operations.variables.conformances
                    }
                }
                return conformances
            }
        }
    }

    func write(using fileOutput: FileOutput, typeScope: SwiftTypeScope) async throws {
        try validateOutputURLs()
        switch configuration.output.documents.directory {
        case .definition: break
        case .directory(let url):
            await fileOutput.createDirectory(at: url)
        }
        for plannedDocument in documentPlans {
            let document = plannedDocument.document
            var file = SwiftFileWriter()
            file.setHeader(configuration.output.documents.header)
            file.setImports(configuration.output.documents.importedModules)
            var emptyFile = true
            for definition in plannedDocument.definitions {
                switch definition {
                case .operation(let resolvedOperation, let declaration):
                    let operation = try buildOperation(
                        resolvedOperation,
                        typeName: declaration.name,
                        typeScope: typeScope,
                        in: document
                    )
                    file.addType(operation)
                    emptyFile = false
                case .fragment(
                    let resolvedFragment,
                    let includesSelectionSet,
                    let declaration
                ):
                    file.addType(
                        try buildFragment(
                            resolvedFragment,
                            typeName: declaration.name,
                            typeScope: typeScope,
                            includesSelectionSet: includesSelectionSet,
                            in: document
                        )
                    )
                    emptyFile = false
                }
            }
            let outputURL = document.outputURL(configuration)
            if emptyFile {
                await fileOutput.remove(at: outputURL)
            } else {
                try await file.write(to: outputURL, configuration: configuration, using: fileOutput)
            }
        }
        let generated = documentPlans.map { $0.document.outputURL(configuration) }
        let removed = Set(previouslyGenerated).subtracting(generated)
        await fileOutput.remove(at: removed)
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
        typeScope: SwiftTypeScope,
        in document: Document
    ) throws -> SwiftTypeBuildable {
        let operation = OperationBuilder(
            configuration: configuration,
            document: document,
            resolvedOperation: operation,
            typeName: typeName,
            typeScope: typeScope
        )
        return try operation.buildable()
    }

    private func buildFragment(
        _ resolvedFragment: ResolvedFragment,
        typeName: SwiftTypeIdentifier,
        typeScope: SwiftTypeScope,
        includesSelectionSet: Bool,
        in document: Document
    ) throws -> SwiftTypeBuildable {
        let fragment = FragmentBuilder(
            configuration: configuration,
            document: document,
            resolvedFragment: resolvedFragment,
            typeName: typeName,
            typeScope: typeScope,
            includesSelectionSet: includesSelectionSet
        )
        return try fragment.buildable()
    }
}
