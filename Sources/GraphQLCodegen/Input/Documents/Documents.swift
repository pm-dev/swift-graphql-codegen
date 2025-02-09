import Foundation

struct Documents {
    let previouslyGenerated: [URL]
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
        let ast: AST.OperationDefinition
        let sourceText: Substring
        let resolvedText: String?
        let hash: String?
    }

    struct Fragment {
        let file: URL
        let ast: AST.FragmentDefinition
        let sourceText: Substring
    }

    let url: URL
    let definitions: [Definition]
    var generatedSwiftFile: URL {
        url.appendingPathExtension("swift")
    }
}
