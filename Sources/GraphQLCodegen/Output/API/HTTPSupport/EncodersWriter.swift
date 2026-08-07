import Foundation

struct EncodersWriter: APIOutput {
    let hasSubscription: Bool
    let configuration: Configuration
    let relativePath = "HTTPSupport/Encoders.swift"

    var topLevelTypeNames: [SwiftTypeIdentifier] {
        var typeNames = [SwiftTypeIdentifier(swiftName: "HTTPBodyEncoder")]
        if configuration.output.api.HTTPSupport?.enableGETQueries == true {
            typeNames.append(SwiftTypeIdentifier(swiftName: "URLQueryEncoder"))
        }
        if case .automatic = configuration.output.documents.operations.persistedOperations {
            typeNames.append(SwiftTypeIdentifier(swiftName: "AutomaticPersistedOperationPhase"))
        }
        return typeNames
    }

    let typeReferences: Set<SwiftTypeReference> = [
        .init(.foundation, "Data"),
        .init(.foundation, "URLQueryItem"),
        .init(.swift, "Bool"),
        .init(.swift, "String"),
    ]

    private var accessLevel: String {
        configuration.output.api.accessLevel == .public ? "public " : ""
    }

    private var header: String {
        guard let header = configuration.output.api.header else { return "" }
        return "\(header)\n"
    }

    private var includeSubscriptionSupport: Bool {
        hasSubscription && configuration.output.api.HTTPSupport?.subscriptionSupport == true
    }

    private var enableGETQueries: Bool {
        configuration.output.api.HTTPSupport?.enableGETQueries == true
    }

    var source: String {
        if enableGETQueries {
            switch configuration.output.documents.operations.persistedOperations {
            case .automatic: getWithAutomaticPersistedOperations()
            case .registered: getWithRegisteredPersistedOperations()
            case .none: getWithNoPersistedOperations()
            }
        } else {
            switch configuration.output.documents.operations.persistedOperations {
            case .automatic: postWithAutomaticPersistedOperations()
            case .registered: postWithRegisteredPersistedOperations()
            case .none: postWithNoPersistedOperations()
            }
        }
    }

    private func getWithAutomaticPersistedOperations() -> String {
        """
        \(header)import Foundation

        /// A `URLQueryEncoder` converts a GraphQL operation into `URLQueryItem`s for a GET request.
        \(accessLevel)protocol URLQueryEncoder {

            /// Encodes an operation for a GET request.
            /// - Parameters:
            ///   operation: The operation to encode.
            ///   automaticPersistedOperationPhase: The request phase of the automatic persisted operation.
            ///   Pass a `nil` value to indicate persisted operations are not enabled and the operation document
            ///   should always be sent.
            ///   minifyDocument: Pass `true` if the document should remove unnecessary whitespace.
            /// - Returns: An array of `URLQueryItem`s to be used in the GET request as the URL's query component.
            func encode<Operation: GraphQLOperation>(
                operation: Operation,
                automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?,
                minifyDocument: Bool
            ) throws -> [URLQueryItem]
        }

        \(httpBodyEncoderWithAutomaticPersistedOperations())
        """
    }

    private func getWithRegisteredPersistedOperations() -> String {
        """
        \(header)import Foundation

        /// A `URLQueryEncoder` converts a GraphQL query operation into `URLQueryItem`s when a GET request.
        /// is being used.
        \(accessLevel)protocol URLQueryEncoder {

            /// Encodes a query operation for a GET request.
            /// - Parameters:
            ///   query: The query operation to encode.
            /// - Returns: An array of `URLQueryItem`s to be used in the GET request as the URL's query component.
            func encode<Query: GraphQLQuery>(query: Query) throws -> [URLQueryItem]\(subscriptionSupportWithRegisteredPersistedOperations())
        }

        \(httpBodyEncoderWithRegisteredPersistedOperations())
        """
    }

    private func getWithNoPersistedOperations() -> String {
        """
        \(header)import Foundation

        /// A `URLQueryEncoder` converts a GraphQL query operation into `URLQueryItem`s when a GET request.
        /// is being used.
        \(accessLevel)protocol URLQueryEncoder {

            /// Encodes a query operation for a GET request.
            /// - Parameters:
            ///   query: The query operation to encode.
            ///   minifyDocument: Pass `true` if the document should remove unnecessary whitespace.
            /// - Returns: An array of `URLQueryItem`s to be used in the GET request as the URL's query component.
            func encode<Query: GraphQLQuery>(
                query: Query,
                minifyDocument: Bool
            ) throws -> [URLQueryItem]\(subscriptionSupportWithNoPersistedOperations())
        }

        \(httpBodyEncoderWithNoPersistedOperations())
        """
    }

    private func postWithAutomaticPersistedOperations() -> String {
        """
        \(header)import Foundation

        \(httpBodyEncoderWithAutomaticPersistedOperations())
        """
    }

    private func postWithRegisteredPersistedOperations() -> String {
        """
        \(header)import Foundation

        \(httpBodyEncoderWithRegisteredPersistedOperations())
        """
    }

    private func postWithNoPersistedOperations() -> String {
        """
        \(header)import Foundation

        \(httpBodyEncoderWithNoPersistedOperations())
        """
    }

    private func httpBodyEncoderWithAutomaticPersistedOperations() -> String {
        """
        /// A `HTTPBodyEncoder` converts a GraphQL operation into the data to be set as the HTTP body
        /// of a POST request.
        \(accessLevel)protocol HTTPBodyEncoder {

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
        \(accessLevel)enum AutomaticPersistedOperationPhase {

            /// This phase indicates encoders should encode an operation's hash instead of the document
            /// text.
            case initialRequestWithHash

            /// This phase indicates encoders should encode an operation's document text as well as its hash, because
            /// the document's hash was not previously found by the server.
            case persistRequestWithDocument
        }
        """
    }

    private func httpBodyEncoderWithRegisteredPersistedOperations() -> String {
        """
        /// A `HTTPBodyEncoder` converts a GraphQL operation into the data to be set as the HTTP body
        /// of a POST request.
        \(accessLevel)protocol HTTPBodyEncoder {

            /// The value to set as the POST request's "content-type" header.
            var contentType: String { get }

            /// Encodes an operation into body data for a POST request.
            /// - Parameters:
            ///   operation: The GraphQL operation to encode.
            /// - Returns: The encoded data to be set as the HTTP body of the POST request.
            func encode<Operation: GraphQLOperation>(operation: Operation) throws -> Data
        }
        """
    }

    private func httpBodyEncoderWithNoPersistedOperations() -> String {
        """
        /// A `HTTPBodyEncoder` converts a GraphQL operation into the data to be set as the HTTP body
        /// of a POST request.
        \(accessLevel)protocol HTTPBodyEncoder {

            /// The value to set as the POST request's "content-type" header.
            var contentType: String { get }

            /// Encodes an operation into body data for a POST request.
            /// - Parameters:
            ///   operation: The GraphQL operation to encode.
            ///   minifyDocument: Pass `true` if the document should remove unnecessary whitespace.
            /// - Returns: The encoded data to be set as the HTTP body of the POST request.
            func encode<Operation: GraphQLOperation>(
                operation: Operation,
                minifyDocument: Bool
            ) throws -> Data
        }
        """
    }

    private func subscriptionSupportWithRegisteredPersistedOperations() -> String {
        guard includeSubscriptionSupport else { return "" }
        return """


            /// Encodes a subscription operation for a GET request.
            /// - Parameters:
            ///   subscription: The subscription operation to encode.
            /// - Returns: An array of `URLQueryItem`s to be used in the GET request as the URL's query component.
            func encode<Subscription: GraphQLSubscription>(subscription: Subscription) throws -> [URLQueryItem]
        """
    }

    private func subscriptionSupportWithNoPersistedOperations() -> String {
        guard includeSubscriptionSupport else { return "" }
        return """


            /// Encodes a subscription operation for a GET request.
            /// - Parameters:
            ///   subscription: The subscription operation to encode.
            ///   minifyDocument: Pass `true` if the document should remove unnecessary whitespace.
            /// - Returns: An array of `URLQueryItem`s to be used in the GET request as the URL's query component.
            func encode<Subscription: GraphQLSubscription>(
                subscription: Subscription,
                minifyDocument: Bool
            ) throws -> [URLQueryItem]
        """
    }
}
