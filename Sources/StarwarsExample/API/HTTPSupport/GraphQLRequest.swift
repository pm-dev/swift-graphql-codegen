// @generated
import Foundation

/// A `GraphQLRequest` represents a `URLRequest` for a GraphQL operation.
struct GraphQLRequest<Operation: GraphQLOperation> {

    /// The `URLRequest` used to execute a GraphQL request. This property
    /// is not modified after initialization, but callers my mutate this property
    /// to provide further customization such as setting authorization headers, timeouts, etc.
    var urlRequest: URLRequest

    /// The GraphQL endpoint the request will be made to.
    let endpoint: URL

    /// The GraphQL operation executed in the request.
    let operation: Operation

    /// Whether the operation document text should be minified (stripped of unnecessary whitespace) when
    /// sent
    let minifyDocument: Bool

    /// The object used to encode the operation into HTTP body data if this request
    /// is sending the operation's hash and the server responds saying the hash is not recognized,
    /// indicating the request should be sent again, but with the full operation document.
    let persistedOperationBodyEncoder: HTTPBodyEncoder?
}

extension GraphQLRequest {

    /// The decoding function to use by default for decoding the response of a GraphQLRequest.
    /// By default, a JSONDecoder is used to decode response data into a `Operation.Data` instance.
    /// To customize this behavior, provide a custom decoder to the `URLSession.request` function.
    static func defaultDecoder() -> @Sendable (Data) throws -> GraphQLResponse<Operation.Data> {
        { data in try JSONDecoder().decode(GraphQLResponse<Operation.Data>.self, from: data) }
    }

    /// Describes how the `GraphQLRequest` should encode a `GraphQLQuery` operation into its `URLRequest`
    enum QueryStrategy {

        /// Instructs the request to be a GET request without support for automatic persisted queries
        case GET(queryEncoder: URLQueryEncoder = DefaultURLQueryEncoder())

        /// Instructs the request to be a POST request without support for automatic persisted queries
        case POST(bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder())

        /// Instructs the request to be a GET request, enabling automatic persisted queries
        case GETWithAutomaticPersistedOperations(
            queryEncoder: URLQueryEncoder = DefaultURLQueryEncoder(),
            persistRequestBodyEncoder: HTTPBodyEncoder = JSONBodyEncoder()
        )

        /// Instructs the request to be a GET request, enabling automatic persisted queries
        case POSTWithAutomaticPersistedOperations(bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder())
    }

    /// Initializes a new `GraphQLRequest` with a query operation
    /// - Parameters:
    ///   - query: The GraphQLQuery operation the request is for.
    ///   - endpoint: The GraphQL server endpoint.
    ///   - strategy: The option describing whether the request should be a GET or POST and whether
    ///   automatic persisted operations is enabled. By default `GET` is used
    ///   and automatic persisted operations is enabled, meaning a `POST` will be executed with the full
    ///   query document if the initial GET results in a "PersistedQueryNotFound" error.
    ///   - minifyDocument: Whether the query document text should be minified
    ///   (unnecessary whitespace removed) when sent. `true` by default.
    ///   - accept: The value to use in the "accept" header field. By default this is
    ///   "application/graphql-response+json". This field is required by the spec:
    ///   https://graphql.github.io/graphql-over-http/draft/#sec-Accept
    init(
        query: Operation,
        endpoint: URL,
        strategy: QueryStrategy = .GETWithAutomaticPersistedOperations(),
        minifyDocument: Bool = true,
        accept: String = "application/graphql-response+json"
    ) throws where Operation: GraphQLQuery {
        let persistedOperationBodyEncoder: HTTPBodyEncoder?
        switch strategy {
        case .GET(let queryEncoder):
            persistedOperationBodyEncoder = nil
            let url = endpoint.appending(
                queryItems: try queryEncoder.encode(
                    query: query,
                    automaticPersistedOperations: false,
                    minifyDocument: minifyDocument
                )
            )
            self.urlRequest = URLRequest(url: url)
            self.urlRequest.httpMethod = "GET"
        case .POST(let bodyEncoder):
            persistedOperationBodyEncoder = nil
            self.urlRequest = URLRequest(url: endpoint)
            self.urlRequest.httpMethod = "POST"
            self.urlRequest.httpBody = try bodyEncoder.encode(
                operation: query,
                automaticPersistedOperationPhase: nil,
                minifyDocument: minifyDocument
            )
            self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
        case .GETWithAutomaticPersistedOperations(let queryEncoder, let persistRequestBodyEncoder):
            persistedOperationBodyEncoder = persistRequestBodyEncoder
            let url = endpoint.appending(
                queryItems: try queryEncoder.encode(
                    query: query,
                    automaticPersistedOperations: true,
                    minifyDocument: minifyDocument
                )
            )
            self.urlRequest = URLRequest(url: url)
            self.urlRequest.httpMethod = "GET"
        case .POSTWithAutomaticPersistedOperations(let bodyEncoder):
            persistedOperationBodyEncoder = bodyEncoder
            self.urlRequest = URLRequest(url: endpoint)
            self.urlRequest.httpMethod = "POST"
            self.urlRequest.httpBody = try bodyEncoder.encode(
                operation: query,
                automaticPersistedOperationPhase: .initialRequestWithHash,
                minifyDocument: minifyDocument
            )
            self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
        }
        self.urlRequest.setValue(accept, forHTTPHeaderField: "accept")
        self.endpoint = endpoint
        self.operation = query
        self.minifyDocument = minifyDocument
        self.persistedOperationBodyEncoder = persistedOperationBodyEncoder
    }

    /// Initializes a new `GraphQLRequest` with an operation
    /// - Parameters:
    ///   - operation: The GraphQLOperation operation the request is for.
    ///   - endpoint: The GraphQL server endpoint.
    ///   - automaticPersistedOperations: Whether automatic persisted operations is enabled.
    ///   By default this is `true` meaning a subsequent request will be executed with the full
    ///   query document if this initial request results in a "PersistedQueryNotFound" error.
    ///   - minifyDocument: Whether the query document text should be minified
    ///   (unnecessary whitespace removed) when sent. `true` by default.
    ///   - bodyEncoder: The encoder used to serialize the operation into HTTP body data.
    ///   - accept: The value to use in the "accept" header field. By default this is
    ///   "application/graphql-response+json". This field is required by the spec:
    ///   https://graphql.github.io/graphql-over-http/draft/#sec-Accept
    init(
        operation: Operation,
        endpoint: Foundation.URL,
        automaticPersistedOperations: Bool = true,
        minifyDocument: Bool = true,
        bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder(),
        accept: String = "application/graphql-response+json"
    ) throws {
        self.urlRequest = URLRequest(url: endpoint)
        self.urlRequest.httpMethod = "POST"
        self.urlRequest.httpBody = try bodyEncoder.encode(
            operation: operation,
            automaticPersistedOperationPhase: automaticPersistedOperations ? .initialRequestWithHash : nil,
            minifyDocument: minifyDocument
        )
        self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
        self.urlRequest.setValue(accept, forHTTPHeaderField: "accept")
        self.endpoint = endpoint
        self.operation = operation
        self.minifyDocument = minifyDocument
        self.persistedOperationBodyEncoder = automaticPersistedOperations ? bodyEncoder : nil
    }
}