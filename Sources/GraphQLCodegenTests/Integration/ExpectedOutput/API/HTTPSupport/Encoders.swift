// @generated
import Foundation

/// A `URLQueryEncoder` converts a GraphQL query operation into `URLQueryItem`s when a GET request.
/// is being used.
protocol URLQueryEncoder {

    /// Encodes a query operation for a GET request.
    /// - Parameters:
    ///   query: The query operation to encode.
    ///   automaticPersistedOperations: Pass `true` if automatic persisted operations is enabled.
    ///   When automatic persisted operations is enabled, implementations should encode the document's
    ///   hash, rather than the full document text. Note: Only the initial request uses GET. When the
    ///   persisted operation is not found by the server, the subsequent request is sent as a POST.
    ///   minifyDocument: Pass `true` if the document should remove unnecessary whitespace.
    /// - Returns: An array of `URLQueryItem`s to be used in the GET request as the URL's query component.
    func encode<Query: GraphQLQuery>(
        query: Query,
        automaticPersistedOperations: Bool,
        minifyDocument: Bool
    ) throws -> [URLQueryItem]
}

/// A `HTTPBodyEncoder` converts a GraphQL operation into the data to be set as the HTTP body
/// of a POST request.
protocol HTTPBodyEncoder {

    /// The value to set as the POST request's "content-type" header.
    var contentType: String { get }

    /// Encodes an operation into body data for a POST request.
    /// - Parameters:
    ///   operation: The GraphQL operation to encode.
    ///   automaticPersistedOperationPhase: The request phase of the automatic persisted operation.
    ///   Pass a `nil` value to indicate persisted operations are not enabled and the operation document
    ///   should always be sent.
    ///   minifyDocument: Pass `true` if the document should remove unnecessary whitespace.
    /// - Returns: The encoded data to be set as the HTTP body of the POST request.
    func encode<Operation: GraphQLOperation>(
        operation: Operation,
        automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?,
        minifyDocument: Bool
    ) throws -> Data
}

/// Indicates which phase of Automatic Persisted Operations the request is for.
enum AutomaticPersistedOperationPhase {

    /// This phase indicates encoders should encode an operation's hash instead of the document
    /// text.
    case initialRequestWithHash

    /// This phase indicates encoders should encode an operation's document text as well as its hash, because
    /// the document's hash was not previously found by the server.
    case persistRequestWithDocument
}