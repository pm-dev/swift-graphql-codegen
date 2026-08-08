import CryptoKit
import Foundation

struct DocumentsLoader {
    private enum ParsedDefinition {
        case fragment(String)
        case operation(
            ast: GraphQLAST.OperationDefinition,
            sourceColumn: Int,
            sourceLine: Int,
            sourceText: Substring
        )
    }

    private struct ParsedDocument {
        let definitions: [ParsedDefinition]
        let relativePath: String
        let url: URL
    }

    let configuration: Configuration
    let graphQLJS: GraphQLJS

    func load() throws -> Documents {
        let documentFiles = try DocumentScanner(
            directories: configuration.input.documentDirectories
        ).scan()
        var fragmentLookup: [String: Document.Fragment] = [:]
        let parsedDocuments = try parse(
            documentFiles,
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
                    let sourceLocation = sourceLocation(
                        atUTF16Offset: operation.loc.start,
                        in: documentText
                    )
                    definitions.append(.operation(
                        ast: operation,
                        sourceColumn: sourceLocation.column,
                        sourceLine: sourceLocation.line,
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
                    let sourceLocation = sourceLocation(
                        atUTF16Offset: fragment.loc.start,
                        in: documentText
                    )
                    definitions.append(.fragment(fragment.name.value))
                    fragmentLookup[fragment.name.value] = Document.Fragment(
                        file: documentURL,
                        ast: fragment,
                        sourceColumn: sourceLocation.column,
                        sourceLine: sourceLocation.line,
                        sourceText: documentText[utf16Range: fragment.loc.utf16Range]
                    )
                }
            }
            documents.append(
                ParsedDocument(
                    definitions: definitions,
                    relativePath: documentFile.relativePath,
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
                case .operation(
                    let operationAST,
                    let operationSourceColumn,
                    let operationSourceLine,
                    let operationSourceText
                ):
                    var referencedFragments: [Document.Fragment] = []
                    let expandedText = try OperationTextResolver(
                        fragmentLookup: fragmentLookup,
                        operationAST: operationAST,
                        operationSourceText: operationSourceText
                    ).expandSourceText { fragment in
                        referencedFragments.append(fragment)
                        return fragment.sourceText
                    }
                    var expandedLine = 1
                    var sourceSegments = [
                        Document.Operation.SourceSegment(
                            expandedLines: expandedLine ..< expandedLine + lineCount(operationSourceText),
                            sourceColumn: operationSourceColumn,
                            sourceLine: operationSourceLine,
                            url: document.url,
                        ),
                    ]
                    expandedLine += lineCount(operationSourceText)
                    for fragment in referencedFragments {
                        let fragmentLineCount = lineCount(fragment.sourceText)
                        sourceSegments.append(
                            Document.Operation.SourceSegment(
                                expandedLines: expandedLine ..< expandedLine + fragmentLineCount,
                                sourceColumn: fragment.sourceColumn,
                                sourceLine: fragment.sourceLine,
                                url: fragment.file
                            )
                        )
                        expandedLine += fragmentLineCount
                    }
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
                                persistence: persistence,
                                sourceSegments: sourceSegments
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

    private func lineCount(_ sourceText: Substring) -> Int {
        sourceText.count(where: \.isNewline) + 1
    }

    private func sourceLocation(atUTF16Offset offset: Int, in sourceText: String) -> (line: Int, column: Int) {
        let sourceIndex = String.Index(utf16Offset: offset, in: sourceText)
        let prefix = sourceText[..<sourceIndex]
        let line = prefix.count(where: \.isNewline) + 1
        let lineStart = prefix.lastIndex(where: \.isNewline).map(prefix.index(after:)) ?? prefix.startIndex
        return (line: line, column: prefix[lineStart...].utf16.count + 1)
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
