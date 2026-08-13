import Foundation

struct DefaultEncodersWriter: SupportOutput {
    let plan: HTTPGenerationPlan
    let configuration: Configuration

    var topLevelTypeNames: [SwiftTypeIdentifier] {
        var typeNames = [SwiftTypeIdentifier(swiftName: "JSONBodyEncoder")]
        if plan.enablesGETQueries {
            typeNames.append(SwiftTypeIdentifier(swiftName: "DefaultURLQueryEncoder"))
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

    private var persistedOperationHashSource: String {
        """
        private func persistedOperationHash(_ document: String) -> String {
            let digits = Array("0123456789abcdef".utf8)
            let capacity = 2 * SHA256.Digest.byteCount
            return String(unsafeUninitializedCapacity: capacity) { buffer -> Int in
                var next = buffer.baseAddress!
                for byte in SHA256.hash(data: Data(document.utf8)) {
                    next[0] = digits[Int(byte >> 4)]
                    next[1] = digits[Int(byte & 0x0f)]
                    next += 2
                }
                return capacity
            }
        }
        """
    }

    private var urlQueryItemsExtensionSource: String {
        let optionalQueryItem = """

                if let query = body.query {
                    items.append(URLEncodedQueryItem(name: "query", value: query))
                }
        """
        let queryItem: String
        switch plan.persistence {
        case .automatic:
            queryItem = optionalQueryItem
        case .registered(let allowsUnregisteredOperations):
            queryItem = allowsUnregisteredOperations ? optionalQueryItem : ""
        case .none:
            queryItem = "\n        items.append(URLEncodedQueryItem(name: \"query\", value: body.query))"
        }

        return """
        private extension [URLEncodedQueryItem] {
            static func from(_ body: Body, jsonEncoder: JSONEncoder) throws -> Self {
                var items = [URLEncodedQueryItem]()
                if let operationName = body.operationName {
                    items.append(URLEncodedQueryItem(name: "operationName", value: operationName))
                }\(queryItem)
                if let variables = body.variables {
                    items.append(
                        URLEncodedQueryItem(
                            name: "variables",
                            value: String(decoding: try jsonEncoder.encode(variables), as: UTF8.self)
                        )
                    )
                }
                if let extensions = body.extensions {
                    items.append(
                        URLEncodedQueryItem(
                            name: "extensions",
                            value: String(decoding: try jsonEncoder.encode(extensions), as: UTF8.self)
                        )
                    )
                }
                return items
            }
        }
        """
    }

    private var includeSubscriptionSupport: Bool {
        plan.includesSubscriptions
    }

    private var registeredOperationParameter: String {
        guard plan.allowsUnregisteredOperations else { return "" }
        return ",\n        useRegisteredOperation: Bool"
    }

    private var registeredOperationArgument: String {
        guard plan.allowsUnregisteredOperations else { return "" }
        return ", useRegisteredOperation: useRegisteredOperation"
    }

    private func getWithAutomaticPersistedOperations() -> String {
        """
        /// A URLQueryEncoder that encodes an operation into `URLEncodedQueryItem`s
        /// using the spec described at:
        /// https://graphql.github.io/graphql-over-http/draft/#sec-GET
        \(accessLevel)struct DefaultURLQueryEncoder: URLQueryEncoder {
            private let jsonEncoder: JSONEncoder

            \(accessLevel)init(jsonEncoder: JSONEncoder = JSONEncoder()) {
                self.jsonEncoder = jsonEncoder
            }

            \(accessLevel)func encode<Operation: GraphQLOperation>(
                operation: Operation,
                automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?
            ) throws -> [URLEncodedQueryItem] {
                try .from(
                    Body(
                        operation: operation,
                        automaticPersistedOperationPhase: automaticPersistedOperationPhase
                    ),
                    jsonEncoder: jsonEncoder
                )
            }
        }

        \(urlQueryItemsExtensionSource)

        \(httpBodyEncoderWithAutomaticPersistedOperations())
        """
    }

    private func getWithRegisteredPersistedOperations() -> String {
        """
        /// A URLQueryEncoder that encodes an operation into `URLEncodedQueryItem`s
        /// using the spec described at:
        /// https://graphql.github.io/graphql-over-http/draft/#sec-GET
        \(accessLevel)struct DefaultURLQueryEncoder: URLQueryEncoder {
            private let jsonEncoder: JSONEncoder

            \(accessLevel)init(jsonEncoder: JSONEncoder = JSONEncoder()) {
                self.jsonEncoder = jsonEncoder
            }

            \(accessLevel)func encode<Query: GraphQLQuery>(
                query: Query\(registeredOperationParameter)
            ) throws -> [URLEncodedQueryItem] {
                try .from(Body(operation: query\(registeredOperationArgument)), jsonEncoder: jsonEncoder)
            }\(subscriptionSupportWithRegisteredPersistedOperations())
        }

        \(urlQueryItemsExtensionSource)

        \(httpBodyEncoderWithRegisteredPersistedOperations())
        """
    }

    private func getWithNoPersistedOperations() -> String {
        """
        /// A URLQueryEncoder that encodes an operation into `URLEncodedQueryItem`s
        /// using the spec described at:
        /// https://graphql.github.io/graphql-over-http/draft/#sec-GET
        \(accessLevel)struct DefaultURLQueryEncoder: URLQueryEncoder {
            private let jsonEncoder: JSONEncoder

            \(accessLevel)init(jsonEncoder: JSONEncoder = JSONEncoder()) {
                self.jsonEncoder = jsonEncoder
            }

            \(accessLevel)func encode<Query: GraphQLQuery>(query: Query) throws -> [URLEncodedQueryItem] {
                try .from(Body(operation: query), jsonEncoder: jsonEncoder)
            }\(subscriptionSupportWithNoPersistedOperations())
        }

        \(urlQueryItemsExtensionSource)

        \(httpBodyEncoderWithNoPersistedOperations())
        """
    }

    private func postWithAutomaticPersistedOperations() -> String {
        """
        \(httpBodyEncoderWithAutomaticPersistedOperations())
        """
    }

    private func postWithRegisteredPersistedOperations() -> String {
        """
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
        /// A HTTPBodyEncoder that encodes an operation into json formatted data
        /// as specified by the spec:
        /// https://graphql.github.io/graphql-over-http/draft/#sec-POST
        \(accessLevel)struct JSONBodyEncoder: HTTPBodyEncoder {
            private let jsonEncoder: JSONEncoder

            \(accessLevel)init(jsonEncoder: JSONEncoder = JSONEncoder()) {
                self.jsonEncoder = jsonEncoder
            }

            \(accessLevel)let contentType = "application/json"
            \(accessLevel)func encode<Operation: GraphQLOperation>(
                operation: Operation,
                automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?
            ) throws -> Data {
                try jsonEncoder.encode(
                    Body(
                        operation: operation,
                        automaticPersistedOperationPhase: automaticPersistedOperationPhase
                    )
                )
            }
        }

        private struct Body: Encodable {
            let operationName: String?
            let query: String?
            let variables: AnyEncodable?
            let extensions: [String: AnyEncodable]?

            init<Operation: GraphQLOperation>(
                operation: Operation,
                automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?
            ) {
                var extensions = operation.extensions
                if automaticPersistedOperationPhase != nil {
                    var persistedExtensions = extensions ?? [:]
                    persistedExtensions["persistedQuery"] = AnyEncodable([
                        "version": AnyEncodable(1),
                        "sha256Hash": AnyEncodable(persistedOperationHash(Operation.document))
                    ])
                    extensions = persistedExtensions
                }
                self.operationName = Operation.operationName
                self.query = automaticPersistedOperationPhase == .initialRequestWithHash ? nil : Operation.document
                self.variables = operation.requestVariables
                self.extensions = extensions
            }
        }

        \(persistedOperationHashSource)
        """
    }

    private func httpBodyEncoderWithRegisteredPersistedOperations() -> String {
        """
        /// A HTTPBodyEncoder that encodes an operation into json formatted data
        /// as specified by the spec:
        /// https://graphql.github.io/graphql-over-http/draft/#sec-POST
        \(accessLevel)struct JSONBodyEncoder: HTTPBodyEncoder {
            private let jsonEncoder: JSONEncoder

            \(accessLevel)init(jsonEncoder: JSONEncoder = JSONEncoder()) {
                self.jsonEncoder = jsonEncoder
            }

            \(accessLevel)let contentType = "application/json"
            \(accessLevel)func encode<Operation: GraphQLOperation>(
                operation: Operation\(registeredOperationParameter)
            ) throws -> Data {
                try jsonEncoder.encode(
                    Body(operation: operation\(registeredOperationArgument))
                )
            }
        }

        \(registeredOperationBody())

        \(persistedOperationHashSource)
        """
    }

    private func registeredOperationBody() -> String {
        guard plan.allowsUnregisteredOperations else {
            return """
            private struct Body: Encodable {
                let operationName: String?
                let variables: AnyEncodable?
                let extensions: [String: AnyEncodable]?

                init<Operation: GraphQLOperation>(operation: Operation) {
                    var extensions = operation.extensions ?? [:]
                    extensions["persistedQuery"] = AnyEncodable([
                        "version": AnyEncodable(1),
                        "sha256Hash": AnyEncodable(persistedOperationHash(Operation.document))
                    ])
                    self.operationName = Operation.operationName
                    self.variables = operation.requestVariables
                    self.extensions = extensions
                }
            }
            """
        }
        return """
        private struct Body: Encodable {
            let operationName: String?
            let query: String?
            let variables: AnyEncodable?
            let extensions: [String: AnyEncodable]?

            init<Operation: GraphQLOperation>(
                operation: Operation,
                useRegisteredOperation: Bool
            ) {
                var extensions = operation.extensions
                if useRegisteredOperation {
                    var registeredExtensions = extensions ?? [:]
                    registeredExtensions["persistedQuery"] = AnyEncodable([
                        "version": AnyEncodable(1),
                        "sha256Hash": AnyEncodable(persistedOperationHash(Operation.document))
                    ])
                    extensions = registeredExtensions
                }
                self.operationName = Operation.operationName
                self.query = useRegisteredOperation ? nil : Operation.document
                self.variables = operation.requestVariables
                self.extensions = extensions
            }
        }
        """
    }

    private func httpBodyEncoderWithNoPersistedOperations() -> String {
        """
        /// A HTTPBodyEncoder that encodes an operation into json formatted data
        /// as specified by the spec:
        /// https://graphql.github.io/graphql-over-http/draft/#sec-POST
        \(accessLevel)struct JSONBodyEncoder: HTTPBodyEncoder {
            private let jsonEncoder: JSONEncoder

            \(accessLevel)init(jsonEncoder: JSONEncoder = JSONEncoder()) {
                self.jsonEncoder = jsonEncoder
            }

            \(accessLevel)let contentType = "application/json"
            \(accessLevel)func encode<Operation: GraphQLOperation>(operation: Operation) throws -> Data {
                try jsonEncoder.encode(Body(operation: operation))
            }
        }

        private struct Body: Encodable {
            let operationName: String?
            let query: String
            let variables: AnyEncodable?
            let extensions: [String: AnyEncodable]?

            init<Operation: GraphQLOperation>(operation: Operation) {
                self.operationName = Operation.operationName
                self.query = Operation.document
                self.variables = operation.requestVariables
                self.extensions = operation.extensions
            }

        }
        """
    }

    private func subscriptionSupportWithRegisteredPersistedOperations() -> String {
        guard includeSubscriptionSupport else { return "" }
        return """


            \(accessLevel)func encode<Subscription: GraphQLSubscription>(
                subscription: Subscription\(registeredOperationParameter)
            ) throws -> [URLEncodedQueryItem] {
                try .from(Body(operation: subscription\(registeredOperationArgument)), jsonEncoder: jsonEncoder)
            }
        """
    }

    private func subscriptionSupportWithNoPersistedOperations() -> String {
        guard includeSubscriptionSupport else { return "" }
        return """


            \(accessLevel)func encode<Subscription: GraphQLSubscription>(subscription: Subscription) throws -> [URLEncodedQueryItem] {
                try .from(Body(operation: subscription), jsonEncoder: jsonEncoder)
            }
        """
    }
}
