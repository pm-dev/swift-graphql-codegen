import CryptoKit
import Foundation

struct DocumentsLoader {
    private struct ParsedDocument {
        let url: URL
        let sourceText: String
        let ast: AST.Document
        let relativePath: String
    }

    let configuration: Configuration
    let graphQLJS: GraphQLJS

    private var shouldHash: Bool {
        switch configuration.output.documents.operations.persistedOperations {
        case .registered: true
        case .automatic, .none: false
        }
    }

    func load() throws -> Documents {
        let scan = try DocumentScanner(directories: configuration.input.documentDirectories).scan()
        var parsedDocuments: [ParsedDocument] = []
        var fragmentLookup: [String: Document.Fragment] = [:]
        for documentURL in scan.documentFileURLs {
            let documentText = try String(contentsOf: documentURL, encoding: .utf8)
            let ast = try DocumentASTParser(
                graphQLJS: graphQLJS,
                sourceText: documentText
            ).parse()
            for definition in ast.definitions {
                guard case .fragment(let fragment) = definition else { continue }
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
                    https://spec.graphql.org/October2021/#sel-IALVDDFDABhCBrE77W
                    """)
                }
                fragmentLookup[fragment.name.value] = Document.Fragment(
                    file: documentURL,
                    ast: fragment,
                    sourceText: documentText[utf16Range: fragment.loc.utf16Range]
                )
            }
            parsedDocuments.append(
                ParsedDocument(
                    url: documentURL,
                    sourceText: documentText,
                    ast: ast,
                    relativePath: try relativePath(for: documentURL)
                )
            )
        }
        return Documents(
            previouslyGenerated: scan.generatedFileURLs,
            documents: try resolvedDocuments(parsedDocuments, fragmentLookup: fragmentLookup),
            fragmentLookup: fragmentLookup
        )
    }

    private func resolvedDocuments(
        _ documents: [ParsedDocument],
        fragmentLookup: [String: Document.Fragment]
    ) throws -> [Document] {
        var resolvedDocuments: [Document] = []
        for document in documents {
            var resolvedDefinitions: [Document.Definition] = []
            for definition in document.ast.definitions {
                switch definition {
                case .operation(let operation):
                    let sourceText = document.sourceText[utf16Range: operation.loc.utf16Range]
                    let resolvedText = try graphQLJS.canonicalize(
                        try OperationTextResolver(
                            operation: operation,
                            sourceText: sourceText,
                            fragmentLookup: fragmentLookup
                        ).expandSourceText { $0.sourceText }
                    )
                    resolvedDefinitions.append(
                        .operation(
                            Document.Operation(
                                ast: operation,
                                sourceText: sourceText,
                                resolvedText: resolvedText,
                                hash: shouldHash ? hash(resolvedText) : nil
                            )
                        )
                    )
                case .fragment(let fragment):
                    resolvedDefinitions.append(.fragment(fragment.name.value))
                }
            }
            resolvedDocuments.append(
                Document(
                    url: document.url,
                    definitions: resolvedDefinitions,
                    relativePath: document.relativePath
                )
            )
        }
        return resolvedDocuments
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
        return String(unsafeUninitializedCapacity: capacity) { ptr -> Int in
            var p = ptr.baseAddress!
            for byte in SHA256.hash(data: Data(sourceText.utf8)) {
                p[0] = digits[Int(byte >> 4)]
                p[1] = digits[Int(byte & 0x0F)]
                p += 2
            }
            return capacity
        }
    }
}
