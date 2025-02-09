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

    let schema: Schema
    let documents: Documents

    func validate() async throws {
        var documentErrors: [DocumentError] = []
        let schemaJSONString = schema.jsonString!
        try await withThrowingTaskGroup(of: DocumentError?.self) { group in
            for document in documents.documents {
                group.addTask {
                    var operationErrors: [OperationError] = []
                    for definition in document.definitions {
                        switch definition {
                        case .operation(let operation):
                            let errors = try DocumentValidator(
                                documentText: operation.resolvedText!,
                                schemaJSONString: schemaJSONString
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
                        return DocumentError(
                            url: document.url,
                            operationErrors: operationErrors
                        )
                    }
                    return nil
                }
            }
            for try await error in group {
                if let error {
                    documentErrors.append(error)
                }
            }
        }
        if !documentErrors.isEmpty {
            throw ValidationError(documentErrors: documentErrors)
        }
    }
}
