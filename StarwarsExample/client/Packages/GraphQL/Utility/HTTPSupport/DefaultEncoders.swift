// @generated
import CryptoKit
import Foundation

/// A URLQueryEncoder that encodes an operation into `URLQueryItem`s
/// using the spec described at:
/// https://graphql.github.io/graphql-over-http/draft/#sec-GET
public struct DefaultURLQueryEncoder: URLQueryEncoder {
    public init() {}
    public func encode<Query: GraphQLQuery>(
        query: Query,
        useRegisteredOperation: Bool
    ) throws -> [URLQueryItem] {
        try .from(Body(operation: query, useRegisteredOperation: useRegisteredOperation))
    }

    public func encode<Subscription: GraphQLSubscription>(
        subscription: Subscription,
        useRegisteredOperation: Bool
    ) throws -> [URLQueryItem] {
        try .from(Body(operation: subscription, useRegisteredOperation: useRegisteredOperation))
    }
}

private extension [URLQueryItem] {
    static func from(_ body: Body) throws -> Self {
        var items = [URLQueryItem]()
        if let operationName = body.operationName {
            items.append(URLQueryItem(name: "operationName", value: operationName))
        }
        if let query = body.query {
            items.append(URLQueryItem(name: "query", value: query))
        }
        if let variables = body.variables {
            items.append(
                URLQueryItem(
                    name: "variables",
                    value: String(decoding: try JSONEncoder().encode(variables), as: UTF8.self)
                )
            )
        }
        if let extensions = body.extensions {
            items.append(
                URLQueryItem(
                    name: "extensions",
                    value: String(decoding: try JSONEncoder().encode(extensions), as: UTF8.self)
                )
            )
        }
        return items
    }
}

/// A HTTPBodyEncoder that encodes an operation into json formatted data
/// as specified by the spec:
/// https://graphql.github.io/graphql-over-http/draft/#sec-POST
public struct JSONBodyEncoder: HTTPBodyEncoder {
    public init() {}
    public let contentType = "application/json"
    public func encode<Operation: GraphQLOperation>(
        operation: Operation,
        useRegisteredOperation: Bool
    ) throws -> Data {
        try JSONEncoder().encode(
            Body(operation: operation, useRegisteredOperation: useRegisteredOperation)
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
        useRegisteredOperation: Bool
    ) {
        var extensions = operation.extensions
        if useRegisteredOperation {
            var registeredExtensions = extensions ?? [:]
            registeredExtensions["persistedQuery"] = AnyEncodable([
                "version": AnyEncodable(1),
                "sha256Hash": AnyEncodable(persistedOperationHash(Operation.document))
            ])
            extensions = registeredExtensions
        }
        self.operationName = Operation.operationName
        self.query = useRegisteredOperation ? nil : Operation.document
        self.variables = operation.requestVariables
        self.extensions = extensions
    }
}

private func persistedOperationHash(_ document: String) -> String {
    let digits = Array("0123456789abcdef".utf8)
    let capacity = 2 * SHA256.Digest.byteCount
    return String(unsafeUninitializedCapacity: capacity) { buffer -> Int in
        var next = buffer.baseAddress!
        for byte in SHA256.hash(data: Data(document.utf8)) {
            next[0] = digits[Int(byte >> 4)]
            next[1] = digits[Int(byte & 0x0f)]
            next += 2
        }
        return capacity
    }
}