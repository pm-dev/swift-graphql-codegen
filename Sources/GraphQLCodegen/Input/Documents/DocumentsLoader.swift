import CryptoKit
import Foundation

struct DocumentsLoader {
    let configuration: Configuration

    private var shouldResolve: Bool {
        configuration.validation || shouldHash
    }

    private var shouldHash: Bool {
        switch configuration.output.documents.operations.persistedOperations {
        case .registered: true
        case .automatic, .none: false
        }
    }

    func load() throws -> Documents {
        let scan = try DocumentScanner(directories: configuration.input.documentDirectories).scan()
        var documents: [Document] = []
        var fragmentLookup: [String: Document.Fragment] = [:]
        for documentURL in scan.documentFileURLs {
            let documentText = try String(contentsOf: documentURL, encoding: .utf8)
            let ast = try DocumentASTParser(sourceText: documentText).parse()
            var definitions: [Document.Definition] = []
            for definition in ast.definitions {
                switch definition {
                case .operation(let operation):
                    definitions.append(
                        .operation(
                            Document.Operation(
                                ast: operation,
                                sourceText: documentText[operation.loc.range],
                                resolvedText: nil,
                                hash: nil
                            )
                        )
                    )
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
                        https://spec.graphql.org/October2021/#sel-IALVDDFDABhCBrE77W
                        """)
                    }
                    definitions.append(.fragment(fragment.name.value))
                    fragmentLookup[fragment.name.value] = Document.Fragment(
                        file: documentURL,
                        ast: fragment,
                        sourceText: documentText[fragment.loc.range]
                    )
                }
            }
            documents.append(Document(url: documentURL, definitions: definitions))
        }
        return Documents(
            previouslyGenerated: scan.generatedFileURLs,
            documents: shouldResolve ? try resolvedDocuments(documents, fragmentLookup: fragmentLookup) : documents,
            fragmentLookup: fragmentLookup
        )
    }

    private func resolvedDocuments(
        _ documents: [Document],
        fragmentLookup: [String: Document.Fragment]
    ) throws -> [Document] {
        var updatedDocuments: [Document] = []
        for document in documents {
            var updatedDefinitions: [Document.Definition] = []
            for definition in document.definitions {
                switch definition {
                case .operation(let operation):
                    let resolvedText = minify(
                        try OperationTextResolver(
                            operation: operation,
                            fragmentLookup: fragmentLookup
                        ).expandSourceText { $0.sourceText }
                    )
                    updatedDefinitions.append(
                        .operation(
                            Document.Operation(
                                ast: operation.ast,
                                sourceText: operation.sourceText,
                                resolvedText: resolvedText,
                                hash: shouldHash ? hash(resolvedText) : nil
                            )
                        )
                    )
                case .fragment:
                    updatedDefinitions.append(definition)
                }
            }
            updatedDocuments.append(Document(url: document.url, definitions: updatedDefinitions))
        }
        return updatedDocuments
    }

    private func minify(_ sourceText: String) -> String {
        sourceText.components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
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
