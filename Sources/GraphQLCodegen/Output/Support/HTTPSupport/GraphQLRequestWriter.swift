import Foundation

struct GraphQLRequestWriter: SupportOutput {
    let plan: HTTPGenerationPlan
    let configuration: Configuration

    var topLevelTypeNames: [SwiftTypeIdentifier] {
        var typeNames = [SwiftTypeIdentifier(swiftName: "GraphQLRequest")]
        if case .automatic = plan.persistence {
            typeNames.append(SwiftTypeIdentifier(swiftName: "PersistedOperationRetry"))
        }
        return typeNames
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

    private var includeSubscriptionSupport: Bool {
        plan.includesSubscriptions
    }

    private var enableGETQueries: Bool {
        plan.enablesGETQueries
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
                persistedOperationRetry: PersistedOperationRetry?
            ) {
                self.urlRequest = urlRequest
                self.endpoint = endpoint
                self.operation = operation
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
                        automaticPersistedOperationPhase: .persistRequestWithDocument
                    )
                    urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
                }
                return Self(
                    urlRequest: urlRequest,
                    endpoint: endpoint,
                    operation: operation,
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
                            automaticPersistedOperationPhase: .persistRequestWithDocument
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

                /// The retry configuration for an unknown persisted operation.
                let persistedOperationRetry: PersistedOperationRetry?
            """
        case .none, .registered:
            ""
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
                bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder(),
                accept: String = "application/graphql-response+json, application/json;q=0.9"
            ) throws where Operation: GraphQLSingleResponseOperation {
                self.urlRequest = URLRequest(url: endpoint)
                self.urlRequest.httpMethod = "POST"
                self.urlRequest.httpBody = try bodyEncoder.encode(
                    operation: operation,
                    automaticPersistedOperationPhase: automaticPersistedOperations ? .initialRequestWithHash : nil
                )
                self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
                self.urlRequest.setValue(accept, forHTTPHeaderField: "accept")
                self.endpoint = endpoint
                self.operation = operation
                self.persistedOperationRetry = automaticPersistedOperations ? .POST(bodyEncoder: bodyEncoder) : nil
            }
        """
    }

    private func registeredOperationInitializer() -> String {
        guard plan.allowsUnregisteredOperations else { return operationInitializerWithoutPersistence() }
        return """


            /// Initializes a POST request for a registered single-response GraphQL operation.
            \(accessLevel)init(
                operation: Operation,
                endpoint: URL,
                useRegisteredOperation: Bool = true,
                bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder(),
                accept: String = "application/graphql-response+json, application/json;q=0.9"
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
        """
    }

    private func operationInitializerWithoutPersistence() -> String {
        """


            /// Initializes a POST request for a single-response GraphQL operation.
            \(accessLevel)init(
                operation: Operation,
                endpoint: URL,
                bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder(),
                accept: String = "application/graphql-response+json, application/json;q=0.9"
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
            ///   - accept: The value to use in the "accept" header field. By default this is
            ///   "application/graphql-response+json, application/json;q=0.9". This field is required by the spec:
            ///   https://graphql.github.io/graphql-over-http/draft/#sec-Accept
            \(accessLevel)init(
                query: Operation,
                endpoint: URL,
                strategy: QueryStrategy = .GETWithAutomaticPersistedOperations(),
                accept: String = "application/graphql-response+json, application/json;q=0.9"
            ) throws where Operation: GraphQLQuery {
                let persistedOperationRetry: PersistedOperationRetry?
                switch strategy {
                case .GET(let queryEncoder):
                    persistedOperationRetry = nil
                    let url = endpoint.appending(
                        queryItems: try queryEncoder.encode(
                            operation: query,
                            automaticPersistedOperationPhase: nil
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
                        automaticPersistedOperationPhase: nil
                    )
                    self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
                case .GETWithAutomaticPersistedOperations(let queryEncoder, let retryPolicy):
                    persistedOperationRetry = retryPolicy.retry
                    let url = endpoint.appending(
                        queryItems: try queryEncoder.encode(
                            operation: query,
                            automaticPersistedOperationPhase: .initialRequestWithHash
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
                        automaticPersistedOperationPhase: .initialRequestWithHash
                    )
                    self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
                }
                self.urlRequest.setValue(accept, forHTTPHeaderField: "accept")
                self.endpoint = endpoint
                self.operation = query
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
        guard plan.allowsUnregisteredOperations else { return querySupportWithoutPersistence() }
        return """


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
            ///   - useRegisteredOperation: Whether to send the registered operation hash instead of the full document.
            ///   - strategy: The option describing whether the request should be a GET or POST. `GET` by default.
            ///   - accept: The value to use in the "accept" header field. By default this is
            ///   "application/graphql-response+json, application/json;q=0.9". This field is required by the spec:
            ///   https://graphql.github.io/graphql-over-http/draft/#sec-Accept
            \(accessLevel)init(
                query: Operation,
                endpoint: URL,
                useRegisteredOperation: Bool = true,
                strategy: QueryStrategy = .GET(),
                accept: String = "application/graphql-response+json, application/json;q=0.9"
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
            ///   - accept: The value to use in the "accept" header field. By default this is
            ///   "application/graphql-response+json, application/json;q=0.9". This field is required by the spec:
            ///   https://graphql.github.io/graphql-over-http/draft/#sec-Accept
            \(accessLevel)init(
                query: Operation,
                endpoint: URL,
                strategy: QueryStrategy = .GET(),
                accept: String = "application/graphql-response+json, application/json;q=0.9"
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
        \(queryItemEncoding())\(persistedOperationRetryDeclaration())
        \(requestDeclaration())

        extension GraphQLRequest {\(defaultDecoderDeclaration())\(persistedOperationUpdate())\(querySupport)\(operationInitializer())\(subscriptionSupport)
        }
        """
    }

    private func queryItemEncoding() -> String {
        guard enableGETQueries else { return "" }
        return """
        private extension URL {
            func appending(queryItems: [URLEncodedQueryItem]) -> URL {
                var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
                let percentEncodedQuery = queryItems.map(\\.percentEncoded).joined(separator: "&")
                if let existingQuery = components.percentEncodedQuery, !existingQuery.isEmpty {
                    components.percentEncodedQuery = existingQuery + "&" + percentEncodedQuery
                } else {
                    components.percentEncodedQuery = percentEncodedQuery
                }
                return components.url!
            }
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
            \(accessLevel)init(
                subscription: Operation,
                endpoint: URL,
                strategy: SubscriptionStrategy = .GET()
            ) throws where Operation: GraphQLSubscription {
                switch strategy {
                case .GET(let queryEncoder):
                    let url = endpoint.appending(
                        queryItems: try queryEncoder.encode(
                            operation: subscription,
                            automaticPersistedOperationPhase: nil
                        )
                    )
                    self.urlRequest = URLRequest(url: url)
                    self.urlRequest.httpMethod = "GET"
                case .POST(let bodyEncoder):
                    self.urlRequest = URLRequest(url: endpoint)
                    self.urlRequest.httpMethod = "POST"
                    self.urlRequest.httpBody = try bodyEncoder.encode(
                        operation: subscription,
                        automaticPersistedOperationPhase: nil
                    )
                    self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
                }
                self.urlRequest.setValue("text/event-stream", forHTTPHeaderField: "accept")
                self.endpoint = endpoint
                self.operation = subscription
                self.persistedOperationRetry = nil
            }
        """
    }

    private func subscriptionSupportGetWithRegisteredPersistedOperations() -> String {
        guard includeSubscriptionSupport else { return "" }
        guard plan.allowsUnregisteredOperations else {
            return subscriptionSupportGetWithNoPersistedOperations()
        }
        return """


        \(subscriptionStrategyDeclaration())

            /// Initializes a new `GraphQLRequest` with a subscription operation
            /// - Parameters:
            ///   - subscription: The GraphQLSubscription operation the request is for.
            ///   - endpoint: The GraphQL server endpoint.
            ///   - useRegisteredOperation: Whether to send the registered operation hash instead of the full document.
            ///   - strategy: The option describing whether the request should be a GET or POST. `GET` by default.
            \(accessLevel)init(
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
            \(accessLevel)init(
                subscription: Operation,
                endpoint: URL,
                strategy: SubscriptionStrategy = .GET()
            ) throws where Operation: GraphQLSubscription {
                switch strategy {
                case .GET(let queryEncoder):
                    let url = endpoint.appending(
                        queryItems: try queryEncoder.encode(subscription: subscription)
                    )
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

    private func subscriptionSupportPostWithAutomaticPersistedOperations() -> String {
        guard includeSubscriptionSupport else { return "" }
        return """


            /// Initializes a new `GraphQLRequest` with a subscription operation
            /// - Parameters:
            ///   - subscription: The GraphQLSubscription operation the request is for.
            ///   - endpoint: The GraphQL server endpoint.
            ///   - bodyEncoder: The encoder used to serialize the operation into HTTP body data.
            ///
            /// Automatic persisted operations are unavailable because subscription fallback is not supported.
            \(accessLevel)init(
                subscription: Operation,
                endpoint: URL,
                bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder()
            ) throws where Operation: GraphQLSubscription {
                self.urlRequest = URLRequest(url: endpoint)
                self.urlRequest.httpMethod = "POST"
                self.urlRequest.httpBody = try bodyEncoder.encode(
                    operation: subscription,
                    automaticPersistedOperationPhase: nil
                )
                self.urlRequest.setValue(bodyEncoder.contentType, forHTTPHeaderField: "content-type")
                self.urlRequest.setValue("text/event-stream", forHTTPHeaderField: "accept")
                self.endpoint = endpoint
                self.operation = subscription
                self.persistedOperationRetry = nil
            }
        """
    }

    private func subscriptionSupportPostWithRegisteredPersistedOperations() -> String {
        guard includeSubscriptionSupport else { return "" }
        guard plan.allowsUnregisteredOperations else {
            return subscriptionSupportPostWithNoPersistedOperations()
        }
        return """


            /// Initializes a new `GraphQLRequest` with a subscription operation
            /// - Parameters:
            ///   - subscription: The GraphQLSubscription operation the request is for.
            ///   - endpoint: The GraphQL server endpoint.
            ///   - useRegisteredOperation: Whether to send the registered operation hash instead of the full document.
            ///   - bodyEncoder: The encoder used to serialize the operation into HTTP body data.
            \(accessLevel)init(
                subscription: Operation,
                endpoint: URL,
                useRegisteredOperation: Bool = true,
                bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder()
            ) throws where Operation: GraphQLSubscription {
                self.urlRequest = URLRequest(url: endpoint)
                self.urlRequest.httpMethod = "POST"
                self.urlRequest.httpBody = try bodyEncoder.encode(
                    operation: subscription,
                    useRegisteredOperation: useRegisteredOperation
                )
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
}
