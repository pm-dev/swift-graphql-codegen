import Foundation

struct DefaultEncodersWriter: SupportOutput {
    let plan: HTTPGenerationPlan
    let configuration: Configuration
    let relativePath = "HTTPSupport/DefaultEncoders.swift"

    var topLevelTypeNames: [SwiftTypeIdentifier] {
        var typeNames = [SwiftTypeIdentifier(swiftName: "JSONBodyEncoder")]
        if plan.enablesGETQueries {
            typeNames.append(SwiftTypeIdentifier(swiftName: "DefaultURLQueryEncoder"))
        }
        return typeNames
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

    private var registeredOperationQueryItem: String {
        guard plan.allowsUnregisteredOperations else { return "" }
        return "\n            body.query.map { URLQueryItem(name: \"query\", value: $0) },"
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
        \(headerBeforeImports)import CryptoKit
        import Foundation

        /// A URLQueryEncoder that encodes an operation into `URLQueryItem`s
        /// using the spec described at:
        /// https://graphql.github.io/graphql-over-http/draft/#sec-GET
        \(accessLevel)struct DefaultURLQueryEncoder: URLQueryEncoder {
            \(accessLevel)init() {}
            \(accessLevel)func encode<Operation: GraphQLOperation>(
                operation: Operation,
                automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?
            ) throws -> [URLQueryItem] {
                let body = Body(
                    operation: operation,
                    automaticPersistedOperationPhase: automaticPersistedOperationPhase
                )
                let encoder = JSONEncoder()
                return [
                    body.operationName.map { URLQueryItem(name: "operationName", value: $0) },
                    body.query.map { URLQueryItem(name: "query", value: $0) },
                    try body.variables.map { variables in
                        URLQueryItem(
                            name: "variables",
                            value: String(decoding: try encoder.encode(variables), as: UTF8.self)
                        )
                    },
                    try body.extensions.map { extensions in
                        URLQueryItem(
                            name: "extensions",
                            value: String(decoding: try encoder.encode(extensions), as: UTF8.self)
                        )
                    }
                ].compactMap { $0 }
            }
        }

        \(httpBodyEncoderWithAutomaticPersistedOperations())
        """
    }

    private func getWithRegisteredPersistedOperations() -> String {
        """
        \(headerBeforeImports)import CryptoKit
        import Foundation

        /// A URLQueryEncoder that encodes an operation into `URLQueryItem`s
        /// using the spec described at:
        /// https://graphql.github.io/graphql-over-http/draft/#sec-GET
        \(accessLevel)struct DefaultURLQueryEncoder: URLQueryEncoder {
            \(accessLevel)init() {}
            \(accessLevel)func encode<Query: GraphQLQuery>(
                query: Query\(registeredOperationParameter)
            ) throws -> [URLQueryItem] {
                let body = Body(operation: query\(registeredOperationArgument))
                let encoder = JSONEncoder()
                return [
                    body.operationName.map { URLQueryItem(name: "operationName", value: $0) },\(registeredOperationQueryItem)
                    try body.variables.map { variables in
                        URLQueryItem(
                            name: "variables",
                            value: String(decoding: try encoder.encode(variables), as: UTF8.self)
                        )
                    },
                    try body.extensions.map { extensions in
                        URLQueryItem(
                            name: "extensions",
                            value: String(decoding: try encoder.encode(extensions), as: UTF8.self)
                        )
                    }
                ].compactMap { $0 }
            }\(subscriptionSupportWithRegisteredPersistedOperations())
        }

        \(httpBodyEncoderWithRegisteredPersistedOperations())
        """
    }

    private func getWithNoPersistedOperations() -> String {
        """
        \(headerBeforeImports)import Foundation

        /// A URLQueryEncoder that encodes an operation into `URLQueryItem`s
        /// using the spec described at:
        /// https://graphql.github.io/graphql-over-http/draft/#sec-GET
        \(accessLevel)struct DefaultURLQueryEncoder: URLQueryEncoder {
            \(accessLevel)init() {}
            \(accessLevel)func encode<Query: GraphQLQuery>(query: Query) throws -> [URLQueryItem] {
                let body = Body(operation: query)
                let encoder = JSONEncoder()
                return [
                    body.operationName.map { URLQueryItem(name: "operationName", value: $0) },
                    body.query.map { URLQueryItem(name: "query", value: $0) },
                    try body.variables.map { variables in
                        URLQueryItem(
                            name: "variables",
                            value: String(decoding: try encoder.encode(variables), as: UTF8.self)
                        )
                    },
                    try body.extensions.map { extensions in
                        URLQueryItem(
                            name: "extensions",
                            value: String(decoding: try encoder.encode(extensions), as: UTF8.self)
                        )
                    }
                ].compactMap { $0 }
            }\(subscriptionSupportWithNoPersistedOperations())
        }

        \(httpBodyEncoderWithNoPersistedOperations())
        """
    }

    private func postWithAutomaticPersistedOperations() -> String {
        """
        \(headerBeforeImports)import CryptoKit
        import Foundation

        \(httpBodyEncoderWithAutomaticPersistedOperations())
        """
    }

    private func postWithRegisteredPersistedOperations() -> String {
        """
        \(headerBeforeImports)import CryptoKit
        import Foundation

        \(httpBodyEncoderWithRegisteredPersistedOperations())
        """
    }

    private func postWithNoPersistedOperations() -> String {
        """
        \(headerBeforeImports)import Foundation

        \(httpBodyEncoderWithNoPersistedOperations())
        """
    }

    private func httpBodyEncoderWithAutomaticPersistedOperations() -> String {
        """
        /// A HTTPBodyEncoder that encodes an operation into json formatted data
        /// as specified by the spec:
        /// https://graphql.github.io/graphql-over-http/draft/#sec-POST
        \(accessLevel)struct JSONBodyEncoder: HTTPBodyEncoder {
            \(accessLevel)init() {}
            \(accessLevel)let contentType = "application/json"
            \(accessLevel)func encode<Operation: GraphQLOperation>(
                operation: Operation,
                automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?
            ) throws -> Data {
                try JSONEncoder().encode(
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
            \(accessLevel)init() {}
            \(accessLevel)let contentType = "application/json"
            \(accessLevel)func encode<Operation: GraphQLOperation>(
                operation: Operation\(registeredOperationParameter)
            ) throws -> Data {
                try JSONEncoder().encode(
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
            \(accessLevel)init() {}
            \(accessLevel)let contentType = "application/json"
            \(accessLevel)func encode<Operation: GraphQLOperation>(operation: Operation) throws -> Data {
                try JSONEncoder().encode(Body(operation: operation))
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
            ) throws -> [URLQueryItem] {
                let body = Body(operation: subscription\(registeredOperationArgument))
                let encoder = JSONEncoder()
                return [
                    body.operationName.map { URLQueryItem(name: "operationName", value: $0) },\(registeredOperationQueryItem)
                    try body.variables.map { variables in
                        URLQueryItem(
                            name: "variables",
                            value: String(decoding: try encoder.encode(variables), as: UTF8.self)
                        )
                    },
                    try body.extensions.map { extensions in
                        URLQueryItem(
                            name: "extensions",
                            value: String(decoding: try encoder.encode(extensions), as: UTF8.self)
                        )
                    }
                ].compactMap { $0 }
            }
        """
    }

    private func subscriptionSupportWithNoPersistedOperations() -> String {
        guard includeSubscriptionSupport else { return "" }
        return """


            \(accessLevel)func encode<Subscription: GraphQLSubscription>(subscription: Subscription) throws -> [URLQueryItem] {
                let body = Body(operation: subscription)
                let encoder = JSONEncoder()
                return [
                    body.operationName.map { URLQueryItem(name: "operationName", value: $0) },
                    body.query.map { URLQueryItem(name: "query", value: $0) },
                    try body.variables.map { variables in
                        URLQueryItem(
                            name: "variables",
                            value: String(decoding: try encoder.encode(variables), as: UTF8.self)
                        )
                    },
                    try body.extensions.map { extensions in
                        URLQueryItem(
                            name: "extensions",
                            value: String(decoding: try encoder.encode(extensions), as: UTF8.self)
                        )
                    }
                ].compactMap { $0 }
            }
        """
    }
}
