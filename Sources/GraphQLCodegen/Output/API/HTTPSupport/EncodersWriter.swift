import Foundation

struct EncodersWriter {
    let configuration: Configuration

    private var accessLevel: String {
        configuration.output.api.accessLevel == .public ? "public " : ""
    }

    private var header: String {
        guard let header = configuration.output.api.header else { return "" }
        return "\(header)\n"
    }

    private var enableGETQueries: Bool {
        configuration.output.api.HTTPSupport?.enableGETQueries == true
    }

    private var url: URL {
        configuration.output.api.directory.appending(
            path: "HTTPSupport/Encoders.swift",
            directoryHint: .notDirectory
        )
    }

    func write() async throws {
        try await content().write(to: url)
    }

    private func content() -> String {
        if enableGETQueries {
            switch configuration.output.documents.operations.persistedOperations {
            case .automatic: GETWithAutomaticPersistedOperations()
            case .registered: GETWithRegisteredPersistedOperations()
            case .none: GETWithNoPersistedOperations()
            }
        } else {
            switch configuration.output.documents.operations.persistedOperations {
            case .automatic: POSTWithAutomaticPersistedOperations()
            case .registered: POSTWithRegisteredPersistedOperations()
            case .none: POSTWithNoPersistedOperations()
            }
        }
    }

    private func GETWithAutomaticPersistedOperations() -> String {
        """
        \(header)import Foundation

        /// A `URLQueryEncoder` converts a GraphQL query operation into `URLQueryItem`s when a GET request.
        /// is being used.
        \(accessLevel)protocol URLQueryEncoder {

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

        \(HTTPBodyEncoderWithAutomaticPersistedOperations())

        """
    }

    private func GETWithRegisteredPersistedOperations() -> String {
        """
        \(header)import Foundation

        /// A `URLQueryEncoder` converts a GraphQL query operation into `URLQueryItem`s when a GET request.
        /// is being used.
        \(accessLevel)protocol URLQueryEncoder {

            /// Encodes a query operation for a GET request.
            /// - Parameters:
            ///   query: The query operation to encode.
            /// - Returns: An array of `URLQueryItem`s to be used in the GET request as the URL's query component.
            func encode<Query: GraphQLQuery>(query: Query) throws -> [URLQueryItem]
        }

        \(HTTPBodyEncoderWithRegisteredPersistedOperations())

        """
    }

    private func GETWithNoPersistedOperations() -> String {
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
            ) throws -> [URLQueryItem]
        }

        \(HTTPBodyEncoderWithNoPersistedOperations())

        """
    }

    private func POSTWithAutomaticPersistedOperations() -> String {
        """
        \(header)import Foundation

        \(HTTPBodyEncoderWithAutomaticPersistedOperations())

        """
    }

    private func POSTWithRegisteredPersistedOperations() -> String {
        """
        \(header)import Foundation

        \(HTTPBodyEncoderWithRegisteredPersistedOperations())

        """
    }

    private func POSTWithNoPersistedOperations() -> String {
        """
        \(header)import Foundation

        \(HTTPBodyEncoderWithNoPersistedOperations())

        """
    }

    private func HTTPBodyEncoderWithAutomaticPersistedOperations() -> String {
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

    private func HTTPBodyEncoderWithRegisteredPersistedOperations() -> String {
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

    private func HTTPBodyEncoderWithNoPersistedOperations() -> String {
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
}
