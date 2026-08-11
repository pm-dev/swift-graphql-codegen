import Foundation

struct EncodersWriter: SupportOutput {
    let plan: HTTPGenerationPlan
    let configuration: Configuration

    var topLevelTypeNames: [SwiftTypeIdentifier] {
        var typeNames = [SwiftTypeIdentifier(swiftName: "HTTPBodyEncoder")]
        if plan.enablesGETQueries {
            typeNames.append(SwiftTypeIdentifier(swiftName: "URLQueryEncoder"))
        }
        if case .automatic = plan.persistence {
            typeNames.append(SwiftTypeIdentifier(swiftName: "AutomaticPersistedOperationPhase"))
        }
        return typeNames
    }

    private var includeSubscriptionSupport: Bool {
        plan.includesSubscriptions
    }

    var source: String {
        switch plan.mode {
        case .getWithAutomaticPersistence: getWithAutomaticPersistedOperations()
        case .getWithRegisteredPersistence: getWithRegisteredPersistedOperations()
        case .getWithoutPersistence: getWithNoPersistedOperations()
        case .postWithAutomaticPersistence: postWithAutomaticPersistedOperations()
        case .postWithRegisteredPersistence: postWithRegisteredPersistedOperations()
        case .postWithoutPersistence: postWithNoPersistedOperations()
        }
    }

    private func getWithAutomaticPersistedOperations() -> String {
        """
        /// A `URLQueryEncoder` converts a GraphQL operation into `URLQueryItem`s for a GET request.
        \(accessLevel)protocol URLQueryEncoder {

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

        \(httpBodyEncoderWithAutomaticPersistedOperations())
        """
    }

    private func getWithRegisteredPersistedOperations() -> String {
        guard plan.allowsUnregisteredOperations else { return getWithNoPersistedOperations() }
        return """
        /// A `URLQueryEncoder` converts a GraphQL query operation into `URLQueryItem`s when a GET request.
        /// is being used.
        \(accessLevel)protocol URLQueryEncoder {

            /// Encodes a query operation for a GET request.
            /// - Parameters:
            ///   query: The query operation to encode.
            ///   useRegisteredOperation: Whether to send the registered operation hash instead of the full document.
            /// - Returns: An array of `URLQueryItem`s to be used in the GET request as the URL's query component.
            func encode<Query: GraphQLQuery>(
                query: Query,
                useRegisteredOperation: Bool
            ) throws -> [URLQueryItem]\(subscriptionSupportWithRegisteredPersistedOperations())
        }

        \(httpBodyEncoderWithRegisteredPersistedOperations())
        """
    }

    private func getWithNoPersistedOperations() -> String {
        """
        /// A `URLQueryEncoder` converts a GraphQL query operation into `URLQueryItem`s when a GET request.
        /// is being used.
        \(accessLevel)protocol URLQueryEncoder {

            /// Encodes a query operation for a GET request.
            /// - Parameters:
            ///   query: The query operation to encode.
            /// - Returns: An array of `URLQueryItem`s to be used in the GET request as the URL's query component.
            func encode<Query: GraphQLQuery>(query: Query) throws -> [URLQueryItem]\(subscriptionSupportWithNoPersistedOperations())
        }

        \(httpBodyEncoderWithNoPersistedOperations())
        """
    }

    private func postWithAutomaticPersistedOperations() -> String {
        """
        \(httpBodyEncoderWithAutomaticPersistedOperations())
        """
    }

    private func postWithRegisteredPersistedOperations() -> String {
        guard plan.allowsUnregisteredOperations else { return postWithNoPersistedOperations() }
        return """
        \(httpBodyEncoderWithRegisteredPersistedOperations())
        """
    }

    private func postWithNoPersistedOperations() -> String {
        """
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
            /// - Returns: The encoded data to be set as the HTTP body of the POST request.
            func encode<Operation: GraphQLOperation>(
                operation: Operation,
                automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?
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
            ///   useRegisteredOperation: Whether to send the registered operation hash instead of the full document.
            /// - Returns: The encoded data to be set as the HTTP body of the POST request.
            func encode<Operation: GraphQLOperation>(
                operation: Operation,
                useRegisteredOperation: Bool
            ) throws -> Data
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
            /// - Returns: The encoded data to be set as the HTTP body of the POST request.
            func encode<Operation: GraphQLOperation>(operation: Operation) throws -> Data
        }
        """
    }

    private func subscriptionSupportWithRegisteredPersistedOperations() -> String {
        guard includeSubscriptionSupport else { return "" }
        return """


            /// Encodes a subscription operation for a GET request.
            /// - Parameters:
            ///   subscription: The subscription operation to encode.
            ///   useRegisteredOperation: Whether to send the registered operation hash instead of the full document.
            /// - Returns: An array of `URLQueryItem`s to be used in the GET request as the URL's query component.
            func encode<Subscription: GraphQLSubscription>(
                subscription: Subscription,
                useRegisteredOperation: Bool
            ) throws -> [URLQueryItem]
        """
    }

    private func subscriptionSupportWithNoPersistedOperations() -> String {
        guard includeSubscriptionSupport else { return "" }
        return """


            /// Encodes a subscription operation for a GET request.
            /// - Parameters:
            ///   subscription: The subscription operation to encode.
            /// - Returns: An array of `URLQueryItem`s to be used in the GET request as the URL's query component.
            func encode<Subscription: GraphQLSubscription>(subscription: Subscription) throws -> [URLQueryItem]
        """
    }
}
