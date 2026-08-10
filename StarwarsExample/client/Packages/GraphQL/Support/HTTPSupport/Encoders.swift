// @generated
import Foundation

/// A `URLQueryEncoder` converts a GraphQL operation into `URLQueryItem`s for a GET request.
public protocol URLQueryEncoder {

    /// Encodes an operation for a GET request.
    /// - Parameters:
    ///   operation: The operation to encode.
    ///   automaticPersistedOperationPhase: The request phase of the automatic persisted operation.
    ///   Pass a `nil` value to indicate persisted operations are not enabled and the operation document
    ///   should always be sent.
    /// - Returns: An array of `URLQueryItem`s to be used in the GET request as the URL's query component.
    func encode<Operation: GraphQLOperation>(
        operation: Operation,
        automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?
    ) throws -> [URLQueryItem]
}

/// A `HTTPBodyEncoder` converts a GraphQL operation into the data to be set as the HTTP body
/// of a POST request.
public protocol HTTPBodyEncoder {

    /// The value to set as the POST request's "content-type" header.
    var contentType: String { get }

    /// Encodes an operation into body data for a POST request.
    /// - Parameters:
    ///   operation: The GraphQL operation to encode.
    ///   automaticPersistedOperationPhase: The request phase of the automatic persisted operation.
    ///   Pass a `nil` value to indicate persisted operations are not enabled and the operation document
    ///   should always be sent.
    /// - Returns: The encoded data to be set as the HTTP body of the POST request.
    func encode<Operation: GraphQLOperation>(
        operation: Operation,
        automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?
    ) throws -> Data
}

/// Indicates which phase of Automatic Persisted Operations the request is for.
public enum AutomaticPersistedOperationPhase {

    /// This phase indicates encoders should encode an operation's hash instead of the document
    /// text.
    case initialRequestWithHash

    /// This phase indicates encoders should encode an operation's document text as well as its hash, because
    /// the document's hash was not previously found by the server.
    case persistRequestWithDocument
}