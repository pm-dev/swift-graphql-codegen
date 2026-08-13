import Foundation

struct DeprecationUsageValidator {
    struct Diagnostic: CustomStringConvertible {
        struct Issue: CustomStringConvertible {
            struct Location: CustomStringConvertible {
                let line: Int
                let column: Int

                var description: String {
                    "line: \(line), column: \(column)"
                }
            }

            let message: String
            let locations: [Location]

            var description: String {
                "\(message)\n\(locations.map(\.description).joined(separator: "\n"))"
            }
        }

        let documentURL: URL
        let issues: [Issue]

        var description: String {
            """
            File: \(documentURL)

            \(issues.map(\.description).joined(separator: "\n\n"))
            """
        }
    }

    struct ExcludedUsageError: CustomStringConvertible, Error {
        let diagnostics: [Diagnostic]

        var description: String {
            """
            Deprecated schema member usage is excluded:

            \(diagnostics.map(\.description).joined(separator: "\n\n"))
            """
        }
    }

    private struct GraphQLIssue: Decodable {
        struct Location: Decodable {
            let line: Int
            let column: Int
        }

        let message: String
        let locations: [Location]
    }

    let documents: Documents
    let graphQLJS: GraphQLJS
    let policy: Configuration.Input.DeprecationPolicy
    let schemaJSON: String

    func validate() throws -> [Diagnostic] {
        guard !documents.documents.isEmpty else { return [] }

        let argumentsOnly =
            switch policy {
            case .include: true
            case .exclude: false
            }
        let issuesJSON = try graphQLJS.findDeprecatedUsages(
            documents.documents.map(\.sourceText),
            schemaJSON: schemaJSON,
            argumentsOnly: argumentsOnly
        )
        let issuesByDocument = try JSONDecoder().decode([[GraphQLIssue]].self, from: issuesJSON)
        let diagnostics = zip(documents.documents, issuesByDocument).compactMap { pair -> Diagnostic? in
            let (document, graphQLIssues) = pair
            guard !graphQLIssues.isEmpty else { return nil }
            return Diagnostic(
                documentURL: document.url,
                issues: graphQLIssues.map { issue in
                    Diagnostic.Issue(
                        message: issue.message,
                        locations: issue.locations.map { location in
                            Diagnostic.Issue.Location(
                                line: location.line,
                                column: location.column
                            )
                        }
                    )
                }
            )
        }

        if case .exclude = policy, !diagnostics.isEmpty {
            throw ExcludedUsageError(diagnostics: diagnostics)
        }
        return diagnostics
    }
}
