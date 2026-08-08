import Foundation

struct DeprecationUsageValidator {
    struct Diagnostic: CustomStringConvertible {
        struct Issue: Decodable, CustomStringConvertible {
            struct Location: Decodable, CustomStringConvertible {
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
        let operationName: String?
        let issues: [Issue]

        var description: String {
            """
            File: \(documentURL)
            Operation: \(operationName ?? "<unnamed>")

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

    let documents: Documents
    let graphQLJS: GraphQLJS
    let policy: Configuration.Input.DeprecationPolicy
    let schemaJSON: String

    func validate() throws -> [Diagnostic] {
        let operationsByDocument = documents.documents.map { document in
            document.definitions.compactMap { definition -> Document.Operation? in
                guard case .operation(let operation) = definition else { return nil }
                return operation
            }
        }
        let operations = operationsByDocument.flatMap { $0 }
        guard !operations.isEmpty else { return [] }

        let argumentsOnly = switch policy {
        case .include: true
        case .exclude: false
        }
        let issuesJSON = try graphQLJS.findDeprecatedUsages(
            operations.map(\.documentText),
            schemaJSON: schemaJSON,
            argumentsOnly: argumentsOnly
        )
        let issuesByOperation = try JSONDecoder().decode([[Diagnostic.Issue]].self, from: issuesJSON)

        var diagnostics: [Diagnostic] = []
        var operationIndex = 0
        for (document, operations) in zip(documents.documents, operationsByDocument) {
            for operation in operations {
                let issues = issuesByOperation[operationIndex]
                operationIndex += 1
                guard !issues.isEmpty else { continue }
                diagnostics.append(
                    Diagnostic(
                        documentURL: document.url,
                        operationName: operation.ast.name?.value,
                        issues: issues
                    )
                )
            }
        }

        if case .exclude = policy, !diagnostics.isEmpty {
            throw ExcludedUsageError(diagnostics: diagnostics)
        }
        return diagnostics
    }
}
