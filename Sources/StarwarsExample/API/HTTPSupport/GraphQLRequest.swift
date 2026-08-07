// @generated
import Foundation

enum PersistedOperationRetry {
    case GET(queryEncoder: URLQueryEncoder)
    case POST(bodyEncoder: HTTPBodyEncoder)
}

/// A `GraphQLRequest` represents a `URLRequest` for a GraphQL operation.
struct GraphQLRequest<Operation: GraphQLOperation> {

    /// The `URLRequest` used to execute a GraphQL request. Callers may mutate this property
    /// after initialization to set authorization headers, timeouts, and other request options.
    var urlRequest: URLRequest

    /// The GraphQL endpoint the request will be made to.
    let endpoint: URL

    /// The GraphQL operation executed in the request.
    let operation: Operation

    /// Whether the request uses the operation's precomputed canonical document.
    let minifyDocument: Bool

    /// The retry configuration for an unknown persisted operation.
    let persistedOperationRetry: PersistedOperationRetry?

    private init(
        urlRequest: URLRequest,
        endpoint: URL,
        operation: Operation,
        minifyDocument: Bool,
        persistedOperationRetry: PersistedOperationRetry?
    ) {
        self.urlRequest = urlRequest
        self.endpoint = endpoint
        self.operation = operation
        self.minifyDocument = minifyDocument
        self.persistedOperationRetry = persistedOperationRetry
    }
}

extension GraphQLRequest {
    /// The decoding function used by default for a GraphQL response.
    static var defaultDecoder: @Sendable (Data) throws -> GraphQLResponse<Operation.Data> {
        { data in try JSONDecoder().decode(GraphQLResponse<Operation.Data>.self, from: data) }
    }

    /// Returns a request updated to retry an unknown persisted operation with its full document.
    func updated(
        for retry: PersistedOperationRetry
    ) throws -> Self where Operation: GraphQLSingleResponseOperation {
        var urlRequest = urlRequest
        switch retry {
        case .GET(let queryEncoder):
            urlRequest.url = endpoint.appending(
                queryItems: try queryEncoder.encode(
                    operation: operation,
                    automaticPersistedOperationPhase: .persistRequestWithDocument,
                    minifyDocument: minifyDocument
                )
            )
            urlRequest.httpMethod = "GET"
            urlRequest.httpBody = nil
            urlRequest.setValue(nil, forHTTPHeaderField: "content-type")
        case .POST(let bodyEncoder):
            urlRequest.url = endpoint
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = try bodyEncoder.encode(
                operation: operation,
                automaticPersistedOperationPhase: .persistRequestWithDocument,
                minifyDocument: minifyDocument
            )
            urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
        }
        return Self(
            urlRequest: urlRequest,
            endpoint: endpoint,
            operation: operation,
            minifyDocument: minifyDocument,
            persistedOperationRetry: nil
        )
    }

    /// Describes how the `GraphQLRequest` should encode a `GraphQLQuery` operation into its `URLRequest`
    enum QueryStrategy {

        /// Describes how to retry an automatic persisted operation when its hash is not recognized.
        enum AutomaticPersistedOperationRetryPolicy {

            /// Retries with the full document encoded in the URL query component.
            case GET(queryEncoder: URLQueryEncoder = DefaultURLQueryEncoder())

            /// Retries with the full document encoded in the HTTP body.
            case POST(bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder())

            var retry: PersistedOperationRetry {
                switch self {
                case .GET(let queryEncoder):
                    return .GET(queryEncoder: queryEncoder)
                case .POST(let bodyEncoder):
                    return .POST(bodyEncoder: bodyEncoder)
                }
            }
        }

        /// Instructs the request to be a GET request without support for automatic persisted queries
        case GET(queryEncoder: URLQueryEncoder = DefaultURLQueryEncoder())

        /// Instructs the request to be a POST request without support for automatic persisted queries
        case POST(bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder())

        /// Instructs the request to be a GET request, enabling automatic persisted queries
        case GETWithAutomaticPersistedOperations(
            queryEncoder: URLQueryEncoder = DefaultURLQueryEncoder(),
            retryPolicy: AutomaticPersistedOperationRetryPolicy = .POST()
        )

        /// Instructs the request to be a POST request, enabling automatic persisted queries.
        /// The retry policy must be selected explicitly.
        case POSTWithAutomaticPersistedOperations(
            bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder(),
            retryPolicy: AutomaticPersistedOperationRetryPolicy
        )
    }

    /// Initializes a new `GraphQLRequest` with a query operation
    /// - Parameters:
    ///   - query: The GraphQLQuery operation the request is for.
    ///   - endpoint: The GraphQL server endpoint.
    ///   - strategy: The option describing whether the request should be a GET or POST and whether
    ///   automatic persisted operations is enabled. By default `GET` is used
    ///   and automatic persisted operations is enabled. If the initial request results in a
    ///   "PersistedQueryNotFound" error, the configured retry policy sends the full query document.
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
        let persistedOperationRetry: PersistedOperationRetry?
        switch strategy {
        case .GET(let queryEncoder):
            persistedOperationRetry = nil
            let url = endpoint.appending(
                queryItems: try queryEncoder.encode(
                    operation: query,
                    automaticPersistedOperationPhase: nil,
                    minifyDocument: minifyDocument
                )
            )
            self.urlRequest = URLRequest(url: url)
            self.urlRequest.httpMethod = "GET"
        case .POST(let bodyEncoder):
            persistedOperationRetry = nil
            self.urlRequest = URLRequest(url: endpoint)
            self.urlRequest.httpMethod = "POST"
            self.urlRequest.httpBody = try bodyEncoder.encode(
                operation: query,
                automaticPersistedOperationPhase: nil,
                minifyDocument: minifyDocument
            )
            self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
        case .GETWithAutomaticPersistedOperations(let queryEncoder, let retryPolicy):
            persistedOperationRetry = retryPolicy.retry
            let url = endpoint.appending(
                queryItems: try queryEncoder.encode(
                    operation: query,
                    automaticPersistedOperationPhase: .initialRequestWithHash,
                    minifyDocument: minifyDocument
                )
            )
            self.urlRequest = URLRequest(url: url)
            self.urlRequest.httpMethod = "GET"
        case .POSTWithAutomaticPersistedOperations(let bodyEncoder, let retryPolicy):
            persistedOperationRetry = retryPolicy.retry
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
        self.persistedOperationRetry = persistedOperationRetry
    }

    /// Initializes a POST request for a single-response GraphQL operation.
    init(
        operation: Operation,
        endpoint: Foundation.URL,
        automaticPersistedOperations: Bool = true,
        minifyDocument: Bool = true,
        bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder(),
        accept: String = "application/graphql-response+json"
    ) throws where Operation: GraphQLSingleResponseOperation {
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
        self.persistedOperationRetry = automaticPersistedOperations ? .POST(bodyEncoder: bodyEncoder) : nil
    }

    /// Describes how the `GraphQLRequest` should encode a `GraphQLSubscription` operation into its
    /// `URLRequest`.
    enum SubscriptionStrategy {

        /// Instructs the request to be a GET request.
        case GET(queryEncoder: URLQueryEncoder = DefaultURLQueryEncoder())

        /// Instructs the request to be a POST request.
        case POST(bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder())
    }

    /// Initializes a new `GraphQLRequest` with a subscription operation
    /// - Parameters:
    ///   - subscription: The GraphQLSubscription operation the request is for.
    ///   - endpoint: The GraphQL server endpoint supporting GraphQL over Server-Sent Events.
    ///   - strategy: The option describing whether the request should be a GET or POST. `GET` by default.
    ///   Automatic persisted operations are unavailable because subscription fallback is not supported.
    ///   - minifyDocument: Whether the query document text should be minified
    ///   (unnecessary whitespace removed) when sent. `true` by default.
    init(
        subscription: Operation,
        endpoint: URL,
        strategy: SubscriptionStrategy = .GET(),
        minifyDocument: Bool = true
    ) throws where Operation: GraphQLSubscription {
        switch strategy {
        case .GET(let queryEncoder):
            let url = endpoint.appending(
                queryItems: try queryEncoder.encode(
                    operation: subscription,
                    automaticPersistedOperationPhase: nil,
                    minifyDocument: minifyDocument
                )
            )
            self.urlRequest = URLRequest(url: url)
            self.urlRequest.httpMethod = "GET"
        case .POST(let bodyEncoder):
            self.urlRequest = URLRequest(url: endpoint)
            self.urlRequest.httpMethod = "POST"
            self.urlRequest.httpBody = try bodyEncoder.encode(
                operation: subscription,
                automaticPersistedOperationPhase: nil,
                minifyDocument: minifyDocument
            )
            self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
        }
        self.urlRequest.setValue("text/event-stream", forHTTPHeaderField: "accept")
        self.endpoint = endpoint
        self.operation = subscription
        self.minifyDocument = minifyDocument
        self.persistedOperationRetry = nil
    }
}