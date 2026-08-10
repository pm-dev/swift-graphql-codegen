// @generated
import Foundation


/// A `GraphQLRequest` represents a `URLRequest` for a GraphQL operation.
public struct GraphQLRequest<Operation: GraphQLOperation> {

    /// The `URLRequest` used to execute a GraphQL request. Callers may mutate this property
    /// after initialization to set authorization headers, timeouts, and other request options.
    public var urlRequest: URLRequest

    /// The GraphQL endpoint the request will be made to.
    public let endpoint: URL

    /// The GraphQL operation executed in the request.
    public let operation: Operation
}

extension GraphQLRequest {
    /// The decoding function used by default for a GraphQL response.
    public static var defaultDecoder: @Sendable (Data) throws -> GraphQLResponse<Operation.Data> {
        { data in try JSONDecoder().decode(GraphQLResponse<Operation.Data>.self, from: data) }
    }

    /// Describes how the `GraphQLRequest` should encode a `GraphQLQuery` operation into its `URLRequest`.
    public enum QueryStrategy {

        /// Instructs the request to be a GET request, encoding the operation into the url query component.
        case GET(queryEncoder: URLQueryEncoder = DefaultURLQueryEncoder())

        /// Instructs the request to be a POST request, encoding the operation into the http body.
        case POST(bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder())
    }

    /// Initializes a new `GraphQLRequest` with a query operation
    /// - Parameters:
    ///   - query: The GraphQLQuery operation the request is for.
    ///   - endpoint: The GraphQL server endpoint.
    ///   - useRegisteredOperation: Whether to send the registered operation hash instead of the full document.
    ///   - strategy: The option describing whether the request should be a GET or POST. `GET` by default.
    ///   - accept: The value to use in the "accept" header field. By default this is
    ///   "application/graphql-response+json". This field is required by the spec:
    ///   https://graphql.github.io/graphql-over-http/draft/#sec-Accept
    public init(
        query: Operation,
        endpoint: URL,
        useRegisteredOperation: Bool = true,
        strategy: QueryStrategy = .GET(),
        accept: String = "application/graphql-response+json"
    ) throws where Operation: GraphQLQuery {
        switch strategy {
        case .GET(let queryEncoder):
            let url = endpoint.appending(
                queryItems: try queryEncoder.encode(
                    query: query,
                    useRegisteredOperation: useRegisteredOperation
                )
            )
            self.urlRequest = URLRequest(url: url)
            self.urlRequest.httpMethod = "GET"
        case .POST(let bodyEncoder):
            self.urlRequest = URLRequest(url: endpoint)
            self.urlRequest.httpMethod = "POST"
            self.urlRequest.httpBody = try bodyEncoder.encode(
                operation: query,
                useRegisteredOperation: useRegisteredOperation
            )
            self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
        }
        self.urlRequest.setValue(accept, forHTTPHeaderField: "accept")
        self.endpoint = endpoint
        self.operation = query
    }

    /// Initializes a POST request for a registered single-response GraphQL operation.
    public init(
        operation: Operation,
        endpoint: URL,
        useRegisteredOperation: Bool = true,
        bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder(),
        accept: String = "application/graphql-response+json"
    ) throws where Operation: GraphQLSingleResponseOperation {
        self.urlRequest = URLRequest(url: endpoint)
        self.urlRequest.httpMethod = "POST"
        self.urlRequest.httpBody = try bodyEncoder.encode(
            operation: operation,
            useRegisteredOperation: useRegisteredOperation
        )
        self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
        self.urlRequest.setValue(accept, forHTTPHeaderField: "accept")
        self.endpoint = endpoint
        self.operation = operation
    }

    /// Describes how the `GraphQLRequest` should encode a `GraphQLSubscription` operation into its
    /// `URLRequest`.
    public enum SubscriptionStrategy {

        /// Instructs the request to be a GET request.
        case GET(queryEncoder: URLQueryEncoder = DefaultURLQueryEncoder())

        /// Instructs the request to be a POST request.
        case POST(bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder())
    }

    /// Initializes a new `GraphQLRequest` with a subscription operation
    /// - Parameters:
    ///   - subscription: The GraphQLSubscription operation the request is for.
    ///   - endpoint: The GraphQL server endpoint.
    ///   - useRegisteredOperation: Whether to send the registered operation hash instead of the full document.
    ///   - strategy: The option describing whether the request should be a GET or POST. `GET` by default.
    public init(
        subscription: Operation,
        endpoint: URL,
        useRegisteredOperation: Bool = true,
        strategy: SubscriptionStrategy = .GET()
    ) throws where Operation: GraphQLSubscription {
        switch strategy {
        case .GET(let queryEncoder):
            let url = endpoint.appending(
                queryItems: try queryEncoder.encode(
                    subscription: subscription,
                    useRegisteredOperation: useRegisteredOperation
                )
            )
            self.urlRequest = URLRequest(url: url)
            self.urlRequest.httpMethod = "GET"
        case .POST(let bodyEncoder):
            self.urlRequest = URLRequest(url: endpoint)
            self.urlRequest.httpMethod = "POST"
            self.urlRequest.httpBody = try bodyEncoder.encode(
                operation: subscription,
                useRegisteredOperation: useRegisteredOperation
            )
            self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
        }
        self.urlRequest.setValue("text/event-stream", forHTTPHeaderField: "accept")
        self.endpoint = endpoint
        self.operation = subscription
    }
}