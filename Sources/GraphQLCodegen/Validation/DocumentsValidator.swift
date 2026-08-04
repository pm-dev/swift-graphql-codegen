import Foundation

struct DocumentsValidator {
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
        var documentErrors: [DocumentError] = []
        for document in documents.documents {
            var operationErrors: [OperationError] = []
            for definition in document.definitions {
                switch definition {
                case .operation(let operation):
                    let errors = try DocumentValidator(
                        documentText: operation.canonicalText,
                        graphQLJS: graphQLJS,
                        schemaJSON: schemaJSON
                    ).validate()
                    if !errors.isEmpty {
                        operationErrors.append(
                            OperationError(
                                operationName: operation.ast.name?.value,
                                errors: errors.map(\.description)
                            )
                        )
                    }
                case .fragment: break
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
