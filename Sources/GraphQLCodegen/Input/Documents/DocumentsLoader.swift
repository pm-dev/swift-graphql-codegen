import CryptoKit
import Foundation

struct DocumentsLoader {
    private enum ParsedDefinition {
        case fragment(String)
        case operation(ast: GraphQLAST.OperationDefinition, sourceText: Substring)
    }

    private struct ParsedDocument {
        let definitions: [ParsedDefinition]
        let relativePath: String
        let url: URL
    }

    let configuration: Configuration
    let graphQLJS: GraphQLJS

    func load() throws -> Documents {
        let documentFileURLs = try DocumentScanner(
            directories: configuration.input.documentDirectories
        ).scan()
        var fragmentLookup: [String: Document.Fragment] = [:]
        let parsedDocuments = try parse(
            documentFileURLs,
            fragmentLookup: &fragmentLookup
        )
        var manifestOperations: [PersistedOperationManifest.Operation] = []
        let preparedDocuments = try prepare(
            parsedDocuments,
            fragmentLookup: fragmentLookup,
            manifestOperations: &manifestOperations
        )
        let persistedOperationManifest: PersistedOperationManifestOutput? =
            switch configuration.output.documents.operations.persistedOperations {
            case .registered(let manifestURL):
                PersistedOperationManifestOutput(
                    operations: manifestOperations,
                    url: manifestURL
                )
            case .automatic, .none:
                nil
            }
        return Documents(
            documents: preparedDocuments,
            fragmentLookup: fragmentLookup,
            persistedOperationManifest: persistedOperationManifest
        )
    }

    private func parse(
        _ documentURLs: [URL],
        fragmentLookup: inout [String: Document.Fragment]
    ) throws -> [ParsedDocument] {
        var documents: [ParsedDocument] = []
        documents.reserveCapacity(documentURLs.count)
        for documentURL in documentURLs {
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
                    relativePath: try relativePath(for: documentURL),
                    url: documentURL
                )
            )
        }
        return documents
    }

    private func prepare(
        _ documents: [ParsedDocument],
        fragmentLookup: [String: Document.Fragment],
        manifestOperations: inout [PersistedOperationManifest.Operation]
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
                    let persistence: Document.Operation.Persistence
                    switch configuration.output.documents.operations.persistedOperations {
                    case .registered:
                        let hash = hash(canonicalText)
                        manifestOperations.append(
                            PersistedOperationManifest.Operation(
                                id: hash,
                                body: canonicalText,
                                name: operationAST.name?.value,
                                type: operationAST.operation.rawValue
                            )
                        )
                        persistence = .registered(hash: hash)
                    case .automatic, .none:
                        persistence = .standard
                    }
                    updatedDefinitions.append(
                        .operation(
                            Document.Operation(
                                ast: operationAST,
                                canonicalText: canonicalText,
                                documentText: expandedText,
                                persistence: persistence
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
                    relativePath: document.relativePath
                )
            )
        }
        return updatedDocuments
    }

    private func relativePath(for documentURL: URL) throws -> String {
        let documentComponents = documentURL.standardizedFileURL.pathComponents
        let sourceRoot = configuration.input.documentDirectories
            .map(\.standardizedFileURL.pathComponents)
            .filter { documentComponents.starts(with: $0) }
            .max { $0.count < $1.count }
        guard let sourceRoot else {
            throw Codegen.Error(description: "Document is outside the configured input directories: \(documentURL)")
        }
        return documentComponents.dropFirst(sourceRoot.count).joined(separator: "/")
    }

    private func hash(_ sourceText: String) -> String {
        let digits = Array("0123456789abcdef".utf8)
        let capacity = 2 * SHA256.Digest.byteCount
        return String(unsafeUninitializedCapacity: capacity) { buffer -> Int in
            var index = 0
            for byte in SHA256.hash(data: Data(sourceText.utf8)) {
                buffer[index] = digits[Int(byte >> 4)]
                buffer[index + 1] = digits[Int(byte & 0x0F)]
                index += 2
            }
            return capacity
        }
    }
}
