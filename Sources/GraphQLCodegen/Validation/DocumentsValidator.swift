import Foundation

struct DocumentsValidator {
    private struct GraphQLError: Decodable {
        struct Location: Decodable {
            let line: Int
            let column: Int

            var description: String {
                "line: \(line), column: \(column)"
            }
        }

        let message: String
        let locations: [Location]

        var description: String {
            """
            \(message)
            \(locations.map(\.description).joined(separator: "\n"))
            """
        }
    }

    struct ValidationError: CustomStringConvertible, Error {
        let documentErrors: [DocumentError]

        var description: String {
            "Validation Failed:\n\n\(documentErrors.map(\.description).joined(separator: "\n\n"))"
        }
    }

    struct DocumentError {
        let url: URL
        let operationErrors: [OperationError]

        var description: String {
            "File: \(url)\n\n\(operationErrors.map(\.description).joined(separator: "\n\n"))"
        }
    }

    struct OperationError {
        let operationName: String?
        let errors: [String]

        var description: String {
            "Operation: \(operationName ?? "<unnamed>")\n\n\(errors.joined(separator: "\n\n"))"
        }
    }

    let schemaJSON: String
    let documents: Documents
    let graphQLJS: GraphQLJS

    func validate() throws {
        let operationsByDocument = documents.documents.map { document in
            document.definitions.compactMap { definition -> Document.Operation? in
                guard case .operation(let operation) = definition else { return nil }
                return operation
            }
        }
        let operations = operationsByDocument.flatMap { $0 }
        guard !operations.isEmpty else { return }

        let errorsJSON = try graphQLJS.validate(
            operations.map(\.canonicalText),
            schemaJSON: schemaJSON
        )
        let validationErrors = try JSONDecoder().decode([[GraphQLError]].self, from: errorsJSON)

        var documentErrors: [DocumentError] = []
        var validationIndex = 0
        for (document, operations) in zip(documents.documents, operationsByDocument) {
            var operationErrors: [OperationError] = []
            for operation in operations {
                let errors = validationErrors[validationIndex]
                validationIndex += 1
                if !errors.isEmpty {
                    operationErrors.append(
                        OperationError(
                            operationName: operation.ast.name?.value,
                            errors: errors.map(\.description)
                        )
                    )
                }
            }
            if !operationErrors.isEmpty {
                documentErrors.append(
                    DocumentError(url: document.url, operationErrors: operationErrors)
                )
            }
        }
        if !documentErrors.isEmpty {
            throw ValidationError(documentErrors: documentErrors)
        }
    }
}
