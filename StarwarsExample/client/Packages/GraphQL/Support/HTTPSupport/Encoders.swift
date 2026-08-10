// @generated
import Foundation

/// A `URLQueryEncoder` converts a GraphQL query operation into `URLQueryItem`s when a GET request.
/// is being used.
public protocol URLQueryEncoder {

    /// Encodes a query operation for a GET request.
    /// - Parameters:
    ///   query: The query operation to encode.
    ///   useRegisteredOperation: Whether to send the registered operation hash instead of the full document.
    /// - Returns: An array of `URLQueryItem`s to be used in the GET request as the URL's query component.
    func encode<Query: GraphQLQuery>(
        query: Query,
        useRegisteredOperation: Bool
    ) throws -> [URLQueryItem]

    /// Encodes a subscription operation for a GET request.
    /// - Parameters:
    ///   subscription: The subscription operation to encode.
    ///   useRegisteredOperation: Whether to send the registered operation hash instead of the full document.
    /// - Returns: An array of `URLQueryItem`s to be used in the GET request as the URL's query component.
    func encode<Subscription: GraphQLSubscription>(
        subscription: Subscription,
        useRegisteredOperation: Bool
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
    ///   useRegisteredOperation: Whether to send the registered operation hash instead of the full document.
    /// - Returns: The encoded data to be set as the HTTP body of the POST request.
    func encode<Operation: GraphQLOperation>(
        operation: Operation,
        useRegisteredOperation: Bool
    ) throws -> Data
}