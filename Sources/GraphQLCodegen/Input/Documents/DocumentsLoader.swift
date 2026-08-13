import Foundation

struct DocumentsLoader {
    private enum ParsedDefinition {
        case fragment(String)
        case operation(ast: GraphQLAST.OperationDefinition, sourceText: Substring)
    }

    private struct ParsedDocument {
        let definitions: [ParsedDefinition]
        let relativePath: String
        let sourceText: String
        let url: URL
    }

    let configuration: Configuration
    let graphQLJS: GraphQLJS

    func load() throws -> Documents {
        let excludedSchemaURL: URL?
        if case .SDLSchemaFile(let schemaFileURL) = configuration.input.schemaSource {
            excludedSchemaURL = schemaFileURL
        } else {
            excludedSchemaURL = nil
        }
        let requiringUniqueFilenames =
            switch configuration.output.documents.directory {
            case .definition: false
            case .directory: true
            }
        let documentFiles = try DocumentScanner(
            directories: configuration.input.documentDirectories
        ).scan(excluding: excludedSchemaURL, requiringUniqueFilenames: requiringUniqueFilenames)
        var fragmentLookup: [String: Document.Fragment] = [:]
        let parsedDocuments = try parse(
            documentFiles,
            fragmentLookup: &fragmentLookup
        )
        let preparedDocuments = try prepare(
            parsedDocuments,
            fragmentLookup: fragmentLookup
        )
        return Documents(
            documents: preparedDocuments,
            fragmentLookup: fragmentLookup
        )
    }

    private func parse(
        _ documentFiles: [DocumentScanner.DocumentFile],
        fragmentLookup: inout [String: Document.Fragment]
    ) throws -> [ParsedDocument] {
        var documents: [ParsedDocument] = []
        documents.reserveCapacity(documentFiles.count)
        for documentFile in documentFiles {
            let documentURL = documentFile.url
            let documentText = try String(contentsOf: documentURL, encoding: .utf8)
            let ast = try DocumentASTParser(
                graphQLJS: graphQLJS,
                sourceText: documentText
            ).parse()
            var definitions: [ParsedDefinition] = []
            definitions.reserveCapacity(ast.definitions.count)
            for definition in ast.definitions {
                switch definition {
                case .operation(let operation):
                    definitions.append(.operation(
                        ast: operation,
                        sourceText: documentText[utf16Range: operation.loc.utf16Range]
                    ))
                case .fragment(let fragment):
                    if let existing = fragmentLookup[fragment.name.value] {
                        throw Codegen.Error(description: """
                        Duplicate fragment name found:
                        Name: \(fragment.name.value)
                        Files:
                        \(existing.file)
                        and
                        \(documentURL)

                        Note: The GraphQL spec requires fragment names to be unique within a document,
                        however, this codegen requires fragment names to be univerally unique.
                        This allows reusing fragments declared in other .graphql files.
                        If you think this is the wrong decision, please open an issue on github
                        and explain your use-case.
                        https://spec.graphql.org/September2025/#sel-IALVDDFDABhCBrE77W
                        """)
                    }
                    definitions.append(.fragment(fragment.name.value))
                    fragmentLookup[fragment.name.value] = Document.Fragment(
                        file: documentURL,
                        ast: fragment,
                        sourceText: documentText[utf16Range: fragment.loc.utf16Range]
                    )
                }
            }
            documents.append(
                ParsedDocument(
                    definitions: definitions,
                    relativePath: documentFile.relativePath,
                    sourceText: documentText,
                    url: documentURL
                )
            )
        }
        return documents
    }

    private func prepare(
        _ documents: [ParsedDocument],
        fragmentLookup: [String: Document.Fragment]
    ) throws -> [Document] {
        var updatedDocuments: [Document] = []
        updatedDocuments.reserveCapacity(documents.count)
        for document in documents {
            var updatedDefinitions: [Document.Definition] = []
            updatedDefinitions.reserveCapacity(document.definitions.count)
            for definition in document.definitions {
                switch definition {
                case .operation(let operationAST, let operationSourceText):
                    let expandedText = try OperationTextResolver(
                        fragmentLookup: fragmentLookup,
                        operationAST: operationAST,
                        operationSourceText: operationSourceText
                    ).expandSourceText { $0.sourceText }
                    let canonicalText = try graphQLJS.canonicalize(expandedText)
                    updatedDefinitions.append(
                        .operation(
                            Document.Operation(
                                ast: operationAST,
                                canonicalText: canonicalText,
                                documentText: expandedText
                            )
                        )
                    )
                case .fragment(let name):
                    updatedDefinitions.append(.fragment(name))
                }
            }
            updatedDocuments.append(
                Document(
                    url: document.url,
                    definitions: updatedDefinitions,
                    relativePath: document.relativePath,
                    sourceText: document.sourceText
                )
            )
        }
        return updatedDocuments
    }
}
