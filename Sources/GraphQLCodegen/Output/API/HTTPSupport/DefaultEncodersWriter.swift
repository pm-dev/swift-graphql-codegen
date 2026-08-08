import Foundation

struct DefaultEncodersWriter: APIOutput {
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

    private var automaticPersistedOperationHashSource: String {
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

    var source: String {
        switch (plan.enablesGETQueries, plan.persistence) {
        case (true, .automatic): getWithAutomaticPersistedOperations()
        case (true, .registered): getWithRegisteredPersistedOperations()
        case (true, .none): getWithNoPersistedOperations()
        case (false, .automatic): postWithAutomaticPersistedOperations()
        case (false, .registered): postWithRegisteredPersistedOperations()
        case (false, .none): postWithNoPersistedOperations()
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
                automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?,
                minifyDocument: Bool
            ) throws -> [URLQueryItem] {
                let body = Body(
                    operation: operation,
                    automaticPersistedOperationPhase: automaticPersistedOperationPhase,
                    minifyDocument: minifyDocument
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
            \(accessLevel)func encode<Query: GraphQLQuery>(
                query: Query,
                minifyDocument: Bool
            ) throws -> [URLQueryItem] {
                let body = Body(
                    operation: query,
                    minifyDocument: minifyDocument
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
        \(headerBeforeImports)import Foundation

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
                automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?,
                minifyDocument: Bool
            ) throws -> Data {
                try JSONEncoder().encode(
                    Body(
                        operation: operation,
                        automaticPersistedOperationPhase: automaticPersistedOperationPhase,
                        minifyDocument: minifyDocument
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
                automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?,
                minifyDocument: Bool
            ) {
                let query = minifyDocument ? Operation.minifiedDocument : Operation.document
                let persistedDocument = Operation.minifiedDocument
                var extensions = operation.extensions
                if automaticPersistedOperationPhase != nil {
                    var persistedExtensions = extensions ?? [:]
                    persistedExtensions["persistedQuery"] = AnyEncodable([
                        "version": AnyEncodable(1),
                        "sha256Hash": AnyEncodable(persistedOperationHash(persistedDocument))
                    ])
                    extensions = persistedExtensions
                }
                self.operationName = Operation.operationName
                self.query = automaticPersistedOperationPhase == .initialRequestWithHash ? nil : query
                self.variables = operation.requestVariables
                self.extensions = extensions
            }
        }

        \(automaticPersistedOperationHashSource)
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
            \(accessLevel)func encode<Operation: GraphQLOperation>(operation: Operation) throws -> Data {
                try JSONEncoder().encode(Body(operation: operation))
            }
        }

        private struct Body: Encodable {
            let operationName: String?
            let variables: AnyEncodable?
            let extensions: [String: AnyEncodable]?

            init<Operation: GraphQLOperation>(operation: Operation) {
                var extensions = operation.extensions ?? [:]
                extensions["persistedQuery"] = AnyEncodable([
                    "version": AnyEncodable(1),
                    "sha256Hash": AnyEncodable(Operation.hash)
                ])
                self.operationName = Operation.operationName
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
            \(accessLevel)func encode<Operation: GraphQLOperation>(
                operation: Operation,
                minifyDocument: Bool
            ) throws -> Data {
                try JSONEncoder().encode(
                    Body(
                        operation: operation,
                        minifyDocument: minifyDocument
                    )
                )
            }
        }

        private struct Body: Encodable {
            let operationName: String?
            let query: String
            let variables: AnyEncodable?
            let extensions: [String: AnyEncodable]?

            init<Operation: GraphQLOperation>(
                operation: Operation,
                minifyDocument: Bool
            ) {
                self.operationName = Operation.operationName
                self.query = minifyDocument ? Operation.minifiedDocument : Operation.document
                self.variables = operation.requestVariables
                self.extensions = operation.extensions
            }

        }
        """
    }

    private func subscriptionSupportWithRegisteredPersistedOperations() -> String {
        guard includeSubscriptionSupport else { return "" }
        return """


            \(accessLevel)func encode<Subscription: GraphQLSubscription>(subscription: Subscription) throws -> [URLQueryItem] {
                let body = Body(operation: subscription)
                let encoder = JSONEncoder()
                return [
                    body.operationName.map { URLQueryItem(name: "operationName", value: $0) },
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


            \(accessLevel)func encode<Subscription: GraphQLSubscription>(
                subscription: Subscription,
                minifyDocument: Bool
            ) throws -> [URLQueryItem] {
                let body = Body(
                    operation: subscription,
                    minifyDocument: minifyDocument
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
        """
    }
}
