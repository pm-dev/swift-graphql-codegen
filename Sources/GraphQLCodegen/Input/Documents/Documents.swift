import Foundation

struct Documents {
    let documents: [Document]
    let fragmentLookup: [String: Document.Fragment]

    func fragment(_ name: String) throws -> Document.Fragment {
        guard let fragment = fragmentLookup[name] else {
            throw Codegen.Error(description: """
            Unable to find fragment definition for \(name)

            Note: Turning on validation can help find other similar errors
            """)
        }
        return fragment
    }
}

struct Document: Sendable {
    enum Definition: Sendable {
        case operation(Operation)
        case fragment(String)
    }

    struct Operation: Sendable {
        enum Persistence: Sendable {
            case registered(hash: String)
            case standard
        }

        let ast: GraphQLAST.OperationDefinition
        let canonicalText: String
        let documentText: String
        let persistence: Persistence
    }

    struct Fragment {
        let file: URL
        let ast: GraphQLAST.FragmentDefinition
        let sourceText: Substring
    }

    let url: URL
    let definitions: [Definition]
    let relativePath: String

    func outputURL(_ configuration: Configuration) -> URL {
        switch configuration.output.documents.directory {
        case .definition:
            url.appendingPathExtension("swift")
        case .directory(let outputDirectory):
            outputDirectory.appending(
                path: relativePath + ".swift",
                directoryHint: .notDirectory
            )
        }
    }
}
