import Foundation

struct Documents {
    let documents: [Document]
    let fragmentLookup: [String: Document.Fragment]
    let persistedOperationManifest: PersistedOperationManifestOutput?

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

struct PersistedOperationManifestOutput {
    let operations: [PersistedOperationManifest.Operation]
    let url: URL
}

struct Document: Sendable {
    enum Definition: Sendable {
        case operation(Operation)
        case fragment(String)
    }

    struct Operation: Sendable {
        struct SourceLocation: Sendable {
            let column: Int
            let line: Int
            let url: URL
        }

        struct SourceSegment: Sendable {
            let expandedLines: Range<Int>
            let sourceColumn: Int
            let sourceLine: Int
            let url: URL
        }

        enum Persistence: Sendable {
            case registered(hash: String)
            case standard
        }

        let ast: GraphQLAST.OperationDefinition
        let canonicalText: String
        let documentText: String
        let persistence: Persistence
        let sourceSegments: [SourceSegment]

        func sourceLocation(line: Int, column: Int) -> SourceLocation? {
            guard let segment = sourceSegments.first(where: { $0.expandedLines.contains(line) }) else {
                return nil
            }
            let relativeLine = line - segment.expandedLines.lowerBound
            return SourceLocation(
                column: relativeLine == 0 ? segment.sourceColumn + column - 1 : column,
                line: segment.sourceLine + relativeLine,
                url: segment.url,
            )
        }
    }

    struct Fragment {
        let file: URL
        let ast: GraphQLAST.FragmentDefinition
        let sourceColumn: Int
        let sourceLine: Int
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
