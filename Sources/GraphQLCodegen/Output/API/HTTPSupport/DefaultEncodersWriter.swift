import Foundation

struct DefaultEncodersWriter {
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
            path: "HTTPSupport/DefaultEncoders.swift",
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
        \(header)import CryptoKit
        import Foundation

        /// A URLQueryEncoder that encodes an operation into `URLQueryItem`s
        /// using the spec described at:
        /// https://graphql.github.io/graphql-over-http/draft/#sec-GET
        \(accessLevel)struct DefaultURLQueryEncoder: URLQueryEncoder {
            \(accessLevel)init() {}
            \(accessLevel)func encode<Query: GraphQLQuery>(
                query: Query,
                automaticPersistedOperations: Bool,
                minifyDocument: Bool
            ) throws -> [URLQueryItem] {
                let body = Body(
                    operation: query,
                    automaticPersistedOperationPhase: automaticPersistedOperations ? .initialRequestWithHash : nil,
                    minifyDocument: minifyDocument
                )
                let encoder = JSONEncoder()
                return [
                    URLQueryItem(name: "operationName", value: body.operationName),
                    URLQueryItem(name: "query", value: body.query),
                    URLQueryItem(name: "variables", value: String(data: try encoder.encode(body.variables), encoding: .utf8)),
                    URLQueryItem(name: "extensions", value: try body.extensions.map { extensions in
                        String(data: try encoder.encode(extensions), encoding: .utf8)!
                    })
                ]
            }
        }

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
                let query = minifyDocument ? Body.minify(Operation.document) : Operation.document
                var extensions = operation.extensions
                if automaticPersistedOperationPhase != nil {
                    var _extensions = extensions ?? [:]
                    _extensions["persistedQuery"] = AnyEncodable([
                        "version": AnyEncodable(1),
                        "sha256Hash": AnyEncodable(Body.hash(query))
                    ])
                    extensions = _extensions
                }
                self.operationName = Operation.operationName
                self.query = automaticPersistedOperationPhase == .initialRequestWithHash ? nil : query
                self.variables = AnyEncodable(operation.variables)
                self.extensions = extensions
            }

            private static func minify(_ sourceText: String) -> String {
                sourceText.components(separatedBy: CharacterSet.whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }

            private static func hash(_ sourceText: String) -> String {
                let digits = Array("0123456789abcdef".utf8)
                let capacity = 2 * SHA256.Digest.byteCount
                return String(unsafeUninitializedCapacity: capacity) { ptr -> Int in
                    var p = ptr.baseAddress!
                    for byte in SHA256.hash(data: Data(sourceText.utf8)) {
                        p[0] = digits[Int(byte >> 4)]
                        p[1] = digits[Int(byte & 0x0f)]
                        p += 2
                    }
                    return capacity
                }
            }
        }

        """
    }

    private func GETWithRegisteredPersistedOperations() -> String {
        """
        \(header)import Foundation

        /// A URLQueryEncoder that encodes an operation into `URLQueryItem`s
        /// using the spec described at:
        /// https://graphql.github.io/graphql-over-http/draft/#sec-GET
        \(accessLevel)struct DefaultURLQueryEncoder: URLQueryEncoder {
            \(accessLevel)init() {}
            \(accessLevel)func encode<Query: GraphQLQuery>(query: Query) throws -> [URLQueryItem] {
                let body = Body(operation: query)
                let encoder = JSONEncoder()
                return [
                    URLQueryItem(name: "operationName", value: body.operationName),
                    URLQueryItem(name: "variables", value: String(data: try encoder.encode(body.variables), encoding: .utf8)),
                    URLQueryItem(name: "extensions", value: try body.extensions.map { extensions in
                        String(data: try encoder.encode(extensions), encoding: .utf8)!
                    })
                ]
            }
        }

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
                self.variables = AnyEncodable(operation.variables)
                self.extensions = extensions
            }
        }

        """
    }

    private func GETWithNoPersistedOperations() -> String {
        """
        \(header)import Foundation

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
                    URLQueryItem(name: "operationName", value: body.operationName),
                    URLQueryItem(name: "query", value: body.query),
                    URLQueryItem(name: "variables", value: String(data: try encoder.encode(body.variables), encoding: .utf8)),
                    URLQueryItem(name: "extensions", value: try body.extensions.map { extensions in
                        String(data: try encoder.encode(extensions), encoding: .utf8)!
                    })
                ]
            }
        }

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
                self.query = minifyDocument ? Body.minify(Operation.document) : Operation.document
                self.variables = AnyEncodable(operation.variables)
                self.extensions = operation.extensions
            }

            private static func minify(_ sourceText: String) -> String {
                sourceText.components(separatedBy: CharacterSet.whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }
        }

        """
    }

    private func POSTWithAutomaticPersistedOperations() -> String {
        """
        \(header)import CryptoKit
        import Foundation

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
                let query = minifyDocument ? Body.minify(Operation.document) : Operation.document
                var extensions = operation.extensions
                if automaticPersistedOperationPhase != nil {
                    var _extensions = extensions ?? [:]
                    _extensions["persistedQuery"] = AnyEncodable([
                        "version": AnyEncodable(1),
                        "sha256Hash": AnyEncodable(Body.hash(query))
                    ])
                    extensions = _extensions
                }
                self.operationName = Operation.operationName
                self.query = automaticPersistedOperationPhase == .initialRequestWithHash ? nil : query
                self.variables = AnyEncodable(operation.variables)
                self.extensions = extensions
            }

            private static func minify(_ sourceText: String) -> String {
                sourceText.components(separatedBy: CharacterSet.whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }

            private static func hash(_ sourceText: String) -> String {
                let digits = Array("0123456789abcdef".utf8)
                let capacity = 2 * SHA256.Digest.byteCount
                return String(unsafeUninitializedCapacity: capacity) { ptr -> Int in
                    var p = ptr.baseAddress!
                    for byte in SHA256.hash(data: Data(sourceText.utf8)) {
                        p[0] = digits[Int(byte >> 4)]
                        p[1] = digits[Int(byte & 0x0f)]
                        p += 2
                    }
                    return capacity
                }
            }
        }

        """
    }

    private func POSTWithRegisteredPersistedOperations() -> String {
        """
        \(header)import Foundation

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
                self.variables = AnyEncodable(operation.variables)
                self.extensions = extensions
            }
        }

        """
    }

    private func POSTWithNoPersistedOperations() -> String {
        """
        \(header)import Foundation

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
                self.query = minifyDocument ? Body.minify(Operation.document) : Operation.document
                self.variables = AnyEncodable(operation.variables)
                self.extensions = operation.extensions
            }

            private static func minify(_ sourceText: String) -> String {
                sourceText.components(separatedBy: CharacterSet.whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }
        }

        """
    }
}
