import Foundation

struct GraphQLRequestWriter: APIOutput {
    let plan: HTTPGenerationPlan
    let configuration: Configuration
    let relativePath = "HTTPSupport/GraphQLRequest.swift"

    var topLevelTypeNames: [SwiftTypeIdentifier] {
        var typeNames = [SwiftTypeIdentifier(swiftName: "GraphQLRequest")]
        if case .automatic = plan.persistence {
            typeNames.append(SwiftTypeIdentifier(swiftName: "PersistedOperationRetry"))
        }
        return typeNames
    }

    private var includeSubscriptionSupport: Bool {
        plan.includesSubscriptions
    }

    private var enableGETQueries: Bool {
        plan.enablesGETQueries
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

    private func requestDeclaration() -> String {
        """
        /// A `GraphQLRequest` represents a `URLRequest` for a GraphQL operation.
        \(accessLevel)struct GraphQLRequest<Operation: GraphQLOperation> {

            /// The `URLRequest` used to execute a GraphQL request. Callers may mutate this property
            /// after initialization to set authorization headers, timeouts, and other request options.
            \(accessLevel)var urlRequest: URLRequest

            /// The GraphQL endpoint the request will be made to.
            \(accessLevel)let endpoint: URL

            /// The GraphQL operation executed in the request.
            \(accessLevel)let operation: Operation\(requestStateProperties())\(requestStateInitializer())
        }
        """
    }

    private func requestStateInitializer() -> String {
        guard case .automatic = plan.persistence else { return "" }
        return """


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
        """
    }

    private func persistedOperationRetryDeclaration() -> String {
        guard case .automatic = plan.persistence else { return "" }
        return """
        enum PersistedOperationRetry {
        \(persistedOperationGETRetryCase())
            case POST(bodyEncoder: HTTPBodyEncoder)
        }

        """
    }

    private func persistedOperationGETRetryCase() -> String {
        guard enableGETQueries else { return "" }
        return "    case GET(queryEncoder: URLQueryEncoder)"
    }

    private func persistedOperationUpdate() -> String {
        guard case .automatic = plan.persistence else { return "" }
        return """


            /// Returns a request updated to retry an unknown persisted operation with its full document.
            func updated(
                for retry: PersistedOperationRetry
            ) throws -> Self where Operation: GraphQLSingleResponseOperation {
                var urlRequest = urlRequest
                switch retry {\(persistedOperationGETUpdate())
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
        """
    }

    private func persistedOperationGETUpdate() -> String {
        guard enableGETQueries else { return "" }
        return """

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
        """
    }

    private func requestStateProperties() -> String {
        switch plan.persistence {
        case .automatic:
            """


                /// Whether the request uses the operation's precomputed canonical document.
                \(accessLevel)let minifyDocument: Bool

                /// The retry configuration for an unknown persisted operation.
                let persistedOperationRetry: PersistedOperationRetry?
            """
        case .registered:
            ""
        case .none:
            """


                /// Whether the request uses the operation's precomputed canonical document.
                \(accessLevel)let minifyDocument: Bool
            """
        }
    }

    private func defaultDecoderDeclaration() -> String {
        """

            /// The decoding function used by default for a GraphQL response.
            \(accessLevel)static var defaultDecoder: @Sendable (Data) throws -> GraphQLResponse<Operation.Data> {
                { data in try JSONDecoder().decode(GraphQLResponse<Operation.Data>.self, from: data) }
            }
        """
    }

    private func operationInitializer() -> String {
        switch plan.persistence {
        case .automatic: automaticOperationInitializer()
        case .registered: registeredOperationInitializer()
        case .none: operationInitializerWithoutPersistence()
        }
    }

    private func automaticOperationInitializer() -> String {
        """


            /// Initializes a POST request for a single-response GraphQL operation.
            \(accessLevel)init(
                operation: Operation,
                endpoint: URL,
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
        """
    }

    private func registeredOperationInitializer() -> String {
        """


            /// Initializes a POST request for a registered single-response GraphQL operation.
            \(accessLevel)init(
                operation: Operation,
                endpoint: URL,
                bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder(),
                accept: String = "application/graphql-response+json"
            ) throws where Operation: GraphQLSingleResponseOperation {
                self.urlRequest = URLRequest(url: endpoint)
                self.urlRequest.httpMethod = "POST"
                self.urlRequest.httpBody = try bodyEncoder.encode(operation: operation)
                self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
                self.urlRequest.setValue(accept, forHTTPHeaderField: "accept")
                self.endpoint = endpoint
                self.operation = operation
            }
        """
    }

    private func operationInitializerWithoutPersistence() -> String {
        """


            /// Initializes a POST request for a single-response GraphQL operation.
            \(accessLevel)init(
                operation: Operation,
                endpoint: URL,
                minifyDocument: Bool = true,
                bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder(),
                accept: String = "application/graphql-response+json"
            ) throws where Operation: GraphQLSingleResponseOperation {
                self.urlRequest = URLRequest(url: endpoint)
                self.urlRequest.httpMethod = "POST"
                self.urlRequest.httpBody = try bodyEncoder.encode(
                    operation: operation,
                    minifyDocument: minifyDocument
                )
                self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
                self.urlRequest.setValue(accept, forHTTPHeaderField: "accept")
                self.endpoint = endpoint
                self.operation = operation
                self.minifyDocument = minifyDocument
            }
        """
    }

    private func getWithAutomaticPersistedOperations() -> String {
        requestContent(
            querySupport: automaticQuerySupport(),
            subscriptionSupport: subscriptionSupportGetWithAutomaticPersistedOperations()
        )
    }

    private func automaticQuerySupport() -> String {
        """


            /// Describes how the `GraphQLRequest` should encode a `GraphQLQuery` operation into its `URLRequest`
            \(accessLevel)enum QueryStrategy {

                /// Describes how to retry an automatic persisted operation when its hash is not recognized.
                \(accessLevel)enum AutomaticPersistedOperationRetryPolicy {

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
            \(accessLevel)init(
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
        """
    }

    private func getWithRegisteredPersistedOperations() -> String {
        requestContent(
            querySupport: registeredQuerySupport(),
            subscriptionSupport: subscriptionSupportGetWithRegisteredPersistedOperations()
        )
    }

    private func registeredQuerySupport() -> String {
        """


            /// Describes how the `GraphQLRequest` should encode a `GraphQLQuery` operation into its `URLRequest`.
            \(accessLevel)enum QueryStrategy {

                /// Instructs the request to be a GET request, encoding the operation into the url query component.
                case GET(queryEncoder: URLQueryEncoder = DefaultURLQueryEncoder())

                /// Instructs the request to be a POST request, encoding the operation into the http body.
                case POST(bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder())
            }

            /// Initializes a new `GraphQLRequest` with a query operation
            /// - Parameters:
            ///   - query: The GraphQLQuery operation the request is for.
            ///   - endpoint: The GraphQL server endpoint.
            ///   - strategy: The option describing whether the request should be a GET or POST. `GET` by default.
            ///   - accept: The value to use in the "accept" header field. By default this is
            ///   "application/graphql-response+json". This field is required by the spec:
            ///   https://graphql.github.io/graphql-over-http/draft/#sec-Accept
            \(accessLevel)init(
                query: Operation,
                endpoint: URL,
                strategy: QueryStrategy = .GET(),
                accept: String = "application/graphql-response+json"
            ) throws where Operation: GraphQLQuery {
                switch strategy {
                case .GET(let queryEncoder):
                    let url = endpoint.appending(queryItems: try queryEncoder.encode(query: query))
                    self.urlRequest = URLRequest(url: url)
                    self.urlRequest.httpMethod = "GET"
                case .POST(let bodyEncoder):
                    self.urlRequest = URLRequest(url: endpoint)
                    self.urlRequest.httpMethod = "POST"
                    self.urlRequest.httpBody = try bodyEncoder.encode(operation: query)
                    self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
                }
                self.urlRequest.setValue(accept, forHTTPHeaderField: "accept")
                self.endpoint = endpoint
                self.operation = query
            }
        """
    }

    private func getWithNoPersistedOperations() -> String {
        requestContent(
            querySupport: querySupportWithoutPersistence(),
            subscriptionSupport: subscriptionSupportGetWithNoPersistedOperations()
        )
    }

    private func querySupportWithoutPersistence() -> String {
        """


            /// Describes how the `GraphQLRequest` should encode a `GraphQLQuery` operation into its `URLRequest`.
            \(accessLevel)enum QueryStrategy {

                /// Instructs the request to be a GET request, encoding the operation into the url query component.
                case GET(queryEncoder: URLQueryEncoder = DefaultURLQueryEncoder())

                /// Instructs the request to be a POST request, encoding the operation into the http body.
                case POST(bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder())
            }

            /// Initializes a new `GraphQLRequest` with a query operation
            /// - Parameters:
            ///   - query: The GraphQLQuery operation the request is for.
            ///   - endpoint: The GraphQL server endpoint.
            ///   - strategy: The option describing whether the request should be a GET or POST. `GET` by default.
            ///   - minifyDocument: Whether the query document text should be minified
            ///   (unnecessary whitespace removed) when sent. `true` by default.
            ///   - accept: The value to use in the "accept" header field. By default this is
            ///   "application/graphql-response+json". This field is required by the spec:
            ///   https://graphql.github.io/graphql-over-http/draft/#sec-Accept
            \(accessLevel)init(
                query: Operation,
                endpoint: URL,
                strategy: QueryStrategy = .GET(),
                minifyDocument: Bool = true,
                accept: String = "application/graphql-response+json"
            ) throws where Operation: GraphQLQuery {
                switch strategy {
                case .GET(let queryEncoder):
                    let url = endpoint.appending(queryItems: try queryEncoder.encode(query: query, minifyDocument: minifyDocument))
                    self.urlRequest = URLRequest(url: url)
                    self.urlRequest.httpMethod = "GET"
                case .POST(let bodyEncoder):
                    self.urlRequest = URLRequest(url: endpoint)
                    self.urlRequest.httpMethod = "POST"
                    self.urlRequest.httpBody = try bodyEncoder.encode(operation: query, minifyDocument: minifyDocument)
                    self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
                }
                self.urlRequest.setValue(accept, forHTTPHeaderField: "accept")
                self.endpoint = endpoint
                self.operation = query
                self.minifyDocument = minifyDocument
            }
        """
    }

    private func postWithAutomaticPersistedOperations() -> String {
        requestContent(subscriptionSupport: subscriptionSupportPostWithAutomaticPersistedOperations())
    }

    private func postWithRegisteredPersistedOperations() -> String {
        requestContent(subscriptionSupport: subscriptionSupportPostWithRegisteredPersistedOperations())
    }

    private func postWithNoPersistedOperations() -> String {
        requestContent(subscriptionSupport: subscriptionSupportPostWithNoPersistedOperations())
    }

    private func requestContent(
        querySupport: String = "",
        subscriptionSupport: String
    ) -> String {
        """
        \(headerBeforeImports)import Foundation

        \(persistedOperationRetryDeclaration())
        \(requestDeclaration())

        extension GraphQLRequest {\(defaultDecoderDeclaration())\(persistedOperationUpdate())\(querySupport)\(operationInitializer())\(subscriptionSupport)
        }
        """
    }

    private func subscriptionStrategyDeclaration() -> String {
        """
            /// Describes how the `GraphQLRequest` should encode a `GraphQLSubscription` operation into its
            /// `URLRequest`.
            \(accessLevel)enum SubscriptionStrategy {

                /// Instructs the request to be a GET request.
                case GET(queryEncoder: URLQueryEncoder = DefaultURLQueryEncoder())

                /// Instructs the request to be a POST request.
                case POST(bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder())
            }
        """
    }

    private func subscriptionSupportGetWithAutomaticPersistedOperations() -> String {
        guard includeSubscriptionSupport else { return "" }
        return """


        \(subscriptionStrategyDeclaration())

            /// Initializes a new `GraphQLRequest` with a subscription operation
            /// - Parameters:
            ///   - subscription: The GraphQLSubscription operation the request is for.
            ///   - endpoint: The GraphQL server endpoint supporting GraphQL over Server-Sent Events.
            ///   - strategy: The option describing whether the request should be a GET or POST. `GET` by default.
            ///   Automatic persisted operations are unavailable because subscription fallback is not supported.
            ///   - minifyDocument: Whether the query document text should be minified
            ///   (unnecessary whitespace removed) when sent. `true` by default.
            \(accessLevel)init(
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
        """
    }

    private func subscriptionSupportGetWithRegisteredPersistedOperations() -> String {
        guard includeSubscriptionSupport else { return "" }
        return """


        \(subscriptionStrategyDeclaration())

            /// Initializes a new `GraphQLRequest` with a subscription operation
            /// - Parameters:
            ///   - subscription: The GraphQLSubscription operation the request is for.
            ///   - endpoint: The GraphQL server endpoint.
            ///   - strategy: The option describing whether the request should be a GET or POST. `GET` by default.
            \(accessLevel)init(
                subscription: Operation,
                endpoint: URL,
                strategy: SubscriptionStrategy = .GET()
            ) throws where Operation: GraphQLSubscription {
                switch strategy {
                case .GET(let queryEncoder):
                    let url = endpoint.appending(queryItems: try queryEncoder.encode(subscription: subscription))
                    self.urlRequest = URLRequest(url: url)
                    self.urlRequest.httpMethod = "GET"
                case .POST(let bodyEncoder):
                    self.urlRequest = URLRequest(url: endpoint)
                    self.urlRequest.httpMethod = "POST"
                    self.urlRequest.httpBody = try bodyEncoder.encode(operation: subscription)
                    self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
                }
                self.urlRequest.setValue("text/event-stream", forHTTPHeaderField: "accept")
                self.endpoint = endpoint
                self.operation = subscription
            }
        """
    }

    private func subscriptionSupportGetWithNoPersistedOperations() -> String {
        guard includeSubscriptionSupport else { return "" }
        return """


        \(subscriptionStrategyDeclaration())

            /// Initializes a new `GraphQLRequest` with a subscription operation
            /// - Parameters:
            ///   - subscription: The GraphQLSubscription operation the request is for.
            ///   - endpoint: The GraphQL server endpoint.
            ///   - strategy: The option describing whether the request should be a GET or POST. `GET` by default.
            ///   - minifyDocument: Whether the query document text should be minified
            ///   (unnecessary whitespace removed) when sent. `true` by default.
            \(accessLevel)init(
                subscription: Operation,
                endpoint: URL,
                strategy: SubscriptionStrategy = .GET(),
                minifyDocument: Bool = true
            ) throws where Operation: GraphQLSubscription {
                switch strategy {
                case .GET(let queryEncoder):
                    let url = endpoint.appending(
                        queryItems: try queryEncoder.encode(subscription: subscription, minifyDocument: minifyDocument)
                    )
                    self.urlRequest = URLRequest(url: url)
                    self.urlRequest.httpMethod = "GET"
                case .POST(let bodyEncoder):
                    self.urlRequest = URLRequest(url: endpoint)
                    self.urlRequest.httpMethod = "POST"
                    self.urlRequest.httpBody = try bodyEncoder.encode(operation: subscription, minifyDocument: minifyDocument)
                    self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
                }
                self.urlRequest.setValue("text/event-stream", forHTTPHeaderField: "accept")
                self.endpoint = endpoint
                self.operation = subscription
                self.minifyDocument = minifyDocument
            }
        """
    }

    private func subscriptionSupportPostWithAutomaticPersistedOperations() -> String {
        guard includeSubscriptionSupport else { return "" }
        return """


            /// Initializes a new `GraphQLRequest` with a subscription operation
            /// - Parameters:
            ///   - subscription: The GraphQLSubscription operation the request is for.
            ///   - endpoint: The GraphQL server endpoint.
            ///   - minifyDocument: Whether the query document text should be minified
            ///   (unnecessary whitespace removed) when sent. `true` by default.
            ///   - bodyEncoder: The encoder used to serialize the operation into HTTP body data.
            ///
            /// Automatic persisted operations are unavailable because subscription fallback is not supported.
            \(accessLevel)init(
                subscription: Operation,
                endpoint: URL,
                minifyDocument: Bool = true,
                bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder()
            ) throws where Operation: GraphQLSubscription {
                self.urlRequest = URLRequest(url: endpoint)
                self.urlRequest.httpMethod = "POST"
                self.urlRequest.httpBody = try bodyEncoder.encode(
                    operation: subscription,
                    automaticPersistedOperationPhase: nil,
                    minifyDocument: minifyDocument
                )
                self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
                self.urlRequest.setValue("text/event-stream", forHTTPHeaderField: "accept")
                self.endpoint = endpoint
                self.operation = subscription
                self.minifyDocument = minifyDocument
                self.persistedOperationRetry = nil
            }
        """
    }

    private func subscriptionSupportPostWithRegisteredPersistedOperations() -> String {
        guard includeSubscriptionSupport else { return "" }
        return """


            /// Initializes a new `GraphQLRequest` with a subscription operation
            /// - Parameters:
            ///   - subscription: The GraphQLSubscription operation the request is for.
            ///   - endpoint: The GraphQL server endpoint.
            ///   - bodyEncoder: The encoder used to serialize the operation into HTTP body data.
            \(accessLevel)init(
                subscription: Operation,
                endpoint: URL,
                bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder()
            ) throws where Operation: GraphQLSubscription {
                self.urlRequest = URLRequest(url: endpoint)
                self.urlRequest.httpMethod = "POST"
                self.urlRequest.httpBody = try bodyEncoder.encode(operation: subscription)
                self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
                self.urlRequest.setValue("text/event-stream", forHTTPHeaderField: "accept")
                self.endpoint = endpoint
                self.operation = subscription
            }
        """
    }

    private func subscriptionSupportPostWithNoPersistedOperations() -> String {
        guard includeSubscriptionSupport else { return "" }
        return """


            /// Initializes a new `GraphQLRequest` with a subscription operation
            /// - Parameters:
            ///   - subscription: The GraphQLSubscription operation the request is for.
            ///   - minifyDocument: Whether the query document text should be minified
            ///   (unnecessary whitespace removed) when sent. `true` by default.
            ///   - endpoint: The GraphQL server endpoint.
            ///   - bodyEncoder: The encoder used to serialize the operation into HTTP body data.
            \(accessLevel)init(
                subscription: Operation,
                endpoint: URL,
                minifyDocument: Bool = true,
                bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder()
            ) throws where Operation: GraphQLSubscription {
                self.urlRequest = URLRequest(url: endpoint)
                self.urlRequest.httpMethod = "POST"
                self.urlRequest.httpBody = try bodyEncoder.encode(
                    operation: subscription,
                    minifyDocument: minifyDocument
                )
                self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
                self.urlRequest.setValue("text/event-stream", forHTTPHeaderField: "accept")
                self.endpoint = endpoint
                self.operation = subscription
                self.minifyDocument = minifyDocument
            }
        """
    }
}
