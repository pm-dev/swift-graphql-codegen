// @generated
import Foundation

/// A URLQueryEncoder that encodes an operation into `URLQueryItem`s
/// using the spec described at:
/// https://graphql.github.io/graphql-over-http/draft/#sec-GET
struct DefaultURLQueryEncoder: URLQueryEncoder {
    init() {}
    func encode<Query: GraphQLQuery>(
        query: Query,
        automaticPersistedOperations: Bool,
        minifyDocument: Bool
    ) throws -> [URLQueryItem] {
        let body = Body(
            operation: query,
            automaticPersistedOperationPhase: automaticPersistedOperations ? .initialRequestWithHash : nil,
            minifyDocument: minifyDocument
        )
        let encoder = JSONEncoder()
        return [
            URLQueryItem(name: "operationName", value: body.operationName),
            URLQueryItem(name: "query", value: body.query),
            URLQueryItem(name: "variables", value: String(data: try encoder.encode(body.variables), encoding: .utf8)),
            URLQueryItem(name: "extensions", value: try body.extensions.map { extensions in
                String(decoding: try encoder.encode(extensions), as: UTF8.self)
            })
        ]
    }
}

/// A HTTPBodyEncoder that encodes an operation into json formatted data
/// as specified by the spec:
/// https://graphql.github.io/graphql-over-http/draft/#sec-POST
struct JSONBodyEncoder: HTTPBodyEncoder {
    init() {}
    let contentType = "application/json"
    func encode<Operation: GraphQLOperation>(
        operation: Operation,
        automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?,
        minifyDocument: Bool
    ) throws -> Data {
        try JSONEncoder().encode(
            Body(
                operation: operation,
                automaticPersistedOperationPhase: automaticPersistedOperationPhase,
                minifyDocument: minifyDocument
            )
        )
    }
}

private struct Body: Encodable {
    let operationName: String?
    let query: String?
    let variables: AnyEncodable?
    let extensions: [String: AnyEncodable]?

    init<Operation: GraphQLOperation>(
        operation: Operation,
        automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?,
        minifyDocument: Bool
    ) {
        let query = minifyDocument ? Operation.minifiedDocument : Operation.document
        var extensions = operation.extensions
        if automaticPersistedOperationPhase != nil {
            var persistedExtensions = extensions ?? [:]
            persistedExtensions["persistedQuery"] = AnyEncodable([
                "version": AnyEncodable(1),
                "sha256Hash": AnyEncodable(
                    minifyDocument ? Operation.minifiedDocumentHash : Operation.documentHash
                )
            ])
            extensions = persistedExtensions
        }
        self.operationName = Operation.operationName
        self.query = automaticPersistedOperationPhase == .initialRequestWithHash ? nil : query
        self.variables = AnyEncodable(operation.variables)
        self.extensions = extensions
    }
}