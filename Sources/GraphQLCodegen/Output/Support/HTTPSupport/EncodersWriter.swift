import Foundation

struct EncodersWriter: SupportOutput {
    let plan: HTTPGenerationPlan
    let configuration: Configuration

    var topLevelTypeNames: [SwiftTypeIdentifier] {
        var typeNames = [SwiftTypeIdentifier(swiftName: "HTTPBodyEncoder")]
        if plan.enablesGETQueries {
            typeNames.append(SwiftTypeIdentifier(swiftName: "URLEncodedQueryItem"))
            typeNames.append(SwiftTypeIdentifier(swiftName: "URLQueryEncoder"))
        }
        if case .automatic = plan.persistence {
            typeNames.append(SwiftTypeIdentifier(swiftName: "AutomaticPersistedOperationPhase"))
        }
        return typeNames
    }

    var source: String {
        switch plan.mode {
        case .getWithAutomaticPersistence: getWithAutomaticPersistedOperations()
        case .getWithRegisteredPersistence: getWithRegisteredPersistedOperations()
        case .getWithoutPersistence: getWithNoPersistedOperations()
        case .postWithAutomaticPersistence: httpBodyEncoderWithAutomaticPersistedOperations()
        case .postWithRegisteredPersistence where plan.allowsUnregisteredOperations:
            httpBodyEncoderWithRegisteredPersistedOperations()
        case .postWithRegisteredPersistence, .postWithoutPersistence:
            httpBodyEncoderWithNoPersistedOperations()
        }
    }

    private func getWithAutomaticPersistedOperations() -> String {
        """
        \(urlEncodedQueryItem())

        /// A `URLQueryEncoder` converts a GraphQL operation into `URLEncodedQueryItem`s for a GET request.
        \(accessLevel)protocol URLQueryEncoder {

            /// Encodes an operation for a GET request.
            /// - Parameters:
            ///   operation: The operation to encode.
            ///   automaticPersistedOperationPhase: The request phase of the automatic persisted operation.
            ///   Pass a `nil` value to indicate persisted operations are not enabled and the operation document
            ///   should always be sent.
            /// - Returns: An array of `URLEncodedQueryItem`s to be used as the URL's query component.
            func encode<Operation: GraphQLOperation>(
                operation: Operation,
                automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?
            ) throws -> [URLEncodedQueryItem]
        }

        \(httpBodyEncoderWithAutomaticPersistedOperations())
        """
    }

    private func getWithRegisteredPersistedOperations() -> String {
        guard plan.allowsUnregisteredOperations else { return getWithNoPersistedOperations() }
        return """
        \(urlEncodedQueryItem())

        /// A `URLQueryEncoder` converts a GraphQL query operation into `URLEncodedQueryItem`s when a GET request.
        /// is being used.
        \(accessLevel)protocol URLQueryEncoder {

            /// Encodes a query operation for a GET request.
            /// - Parameters:
            ///   query: The query operation to encode.
            ///   useRegisteredOperation: Whether to send the registered operation hash instead of the full document.
            /// - Returns: An array of `URLEncodedQueryItem`s to be used as the URL's query component.
            func encode<Query: GraphQLQuery>(
                query: Query,
                useRegisteredOperation: Bool
            ) throws -> [URLEncodedQueryItem]\(subscriptionSupportWithRegisteredPersistedOperations())
        }

        \(httpBodyEncoderWithRegisteredPersistedOperations())
        """
    }

    private func getWithNoPersistedOperations() -> String {
        """
        \(urlEncodedQueryItem())

        /// A `URLQueryEncoder` converts a GraphQL query operation into `URLEncodedQueryItem`s when a GET request.
        /// is being used.
        \(accessLevel)protocol URLQueryEncoder {

            /// Encodes a query operation for a GET request.
            /// - Parameters:
            ///   query: The query operation to encode.
            /// - Returns: An array of `URLEncodedQueryItem`s to be used as the URL's query component.
            func encode<Query: GraphQLQuery>(query: Query) throws -> [URLEncodedQueryItem]\(subscriptionSupportWithNoPersistedOperations())
        }

        \(httpBodyEncoderWithNoPersistedOperations())
        """
    }

    private func urlEncodedQueryItem() -> String {
        """
        /// A name-value pair encoded using `application/x-www-form-urlencoded` rules.
        \(accessLevel)struct URLEncodedQueryItem: Sendable {
            /// The unencoded parameter name.
            \(accessLevel)let name: String

            /// The unencoded parameter value.
            \(accessLevel)let value: String

            \(accessLevel)init(name: String, value: String) {
                self.name = name
                self.value = value
            }

            var percentEncoded: String {
                let allowedCharacters = CharacterSet(
                    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789*-._"
                )
                let name = name.addingPercentEncoding(withAllowedCharacters: allowedCharacters)!
                let value = value.addingPercentEncoding(withAllowedCharacters: allowedCharacters)!
                return (name + "=" + value).replacingOccurrences(of: "%20", with: "+")
            }
        }
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
        guard plan.includesSubscriptions else { return "" }
        return """


            /// Encodes a subscription operation for a GET request.
            /// - Parameters:
            ///   subscription: The subscription operation to encode.
            ///   useRegisteredOperation: Whether to send the registered operation hash instead of the full document.
            /// - Returns: An array of `URLEncodedQueryItem`s to be used as the URL's query component.
            func encode<Subscription: GraphQLSubscription>(
                subscription: Subscription,
                useRegisteredOperation: Bool
            ) throws -> [URLEncodedQueryItem]
        """
    }

    private func subscriptionSupportWithNoPersistedOperations() -> String {
        guard plan.includesSubscriptions else { return "" }
        return """


            /// Encodes a subscription operation for a GET request.
            /// - Parameters:
            ///   subscription: The subscription operation to encode.
            /// - Returns: An array of `URLEncodedQueryItem`s to be used as the URL's query component.
            func encode<Subscription: GraphQLSubscription>(subscription: Subscription) throws -> [URLEncodedQueryItem]
        """
    }
}
