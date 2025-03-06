import Foundation

struct URLSessionWriter {
    let hasSubscription: Bool
    let configuration: Configuration

    private var accessLevel: String {
        configuration.output.api.accessLevel == .public ? "public " : ""
    }

    private var header: String {
        guard let header = configuration.output.api.header else { return "" }
        return "\(header)\n"
    }

    private var includeSubscriptionSupport: Bool {
        hasSubscription && configuration.output.api.HTTPSupport?.subscriptionSupport == true
    }

    private var url: URL {
        configuration.output.api.directory.appending(
            path: "HTTPSupport/URLSession+GraphQL.swift",
            directoryHint: .notDirectory
        )
    }

    func write() async throws {
        try await content().write(to: url)
    }

    private func content() -> String {
        switch configuration.output.documents.operations.persistedOperations {
        case .automatic: automaticPersistedOperations()
        case .registered, .none: noPersistedOperations()
        }
    }

    private func automaticPersistedOperations() -> String {
        """
        \(header)import Foundation

        /// Defaults conform to https://graphql.github.io/graphql-over-http/draft/
        extension URLSession {
            \(accessLevel)struct HTTPError: Error {
                \(accessLevel)let response: HTTPURLResponse
            }

            /// Executes a GraphQL operation
            /// - Parameters:
            ///   - request: The request containing the `URLRequest` to be performed.
            ///   - decoder: The function used to turn response data into an Operation.Data instance.
            \(accessLevel)func request<Operation: GraphQLOperation>(
                _ request: GraphQLRequest<Operation>,
                decoder: (Data) throws -> GraphQLResponse<Operation.Data> = GraphQLRequest<Operation>.defaultDecoder()
            ) async throws -> GraphQLResponse<Operation.Data>.Success {
                let (data, response) = try await data(for: request.urlRequest)
                if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                    throw HTTPError(response: httpResponse)
                }
                switch try decoder(data) {
                case .success(let success): return success
                case .requestError(let requestError):
                    let containsPersistedQueryNotFound = requestError.errors.contains { error in
                        error.message == "PersistedQueryNotFound"
                    }
                    if containsPersistedQueryNotFound,
                       let persistedOperationBodyEncoder = request.persistedOperationBodyEncoder {
                        return try await self.request(
                            try persistingRequest(request, bodyEncoder: persistedOperationBodyEncoder),
                            decoder: decoder
                        )
                    }
                    throw requestError
                }
            }

            private func persistingRequest<Operation: GraphQLOperation>(
                _ original: GraphQLRequest<Operation>,
                bodyEncoder: HTTPBodyEncoder
            ) throws -> GraphQLRequest<Operation> {
                var urlRequest = original.urlRequest
                urlRequest.url = original.endpoint
                urlRequest.httpBody = try bodyEncoder.encode(
                    operation: original.operation,
                    automaticPersistedOperationPhase: .persistRequestWithDocument,
                    minifyDocument: original.minifyDocument
                )
                return GraphQLRequest(
                    urlRequest: urlRequest,
                    endpoint: original.endpoint,
                    operation: original.operation,
                    minifyDocument: original.minifyDocument,
                    persistedOperationBodyEncoder: nil
                )
            }\(subscriptions())
        }
        """
    }

    private func noPersistedOperations() -> String {
        """
        \(header)import Foundation

        /// Defaults conform to https://graphql.github.io/graphql-over-http/draft/
        extension URLSession {
            \(accessLevel)struct HTTPError: Error {
                \(accessLevel)let response: HTTPURLResponse
            }

            /// Executes a GraphQL operation
            /// - Parameters:
            ///   - request: The request containing the `URLRequest` to be performed.
            ///   - decoder: The function used to turn response data into an Operation.Data instance.
            \(accessLevel)func request<Operation: GraphQLOperation>(
                _ request: GraphQLRequest<Operation>,
                decoder: (Data) throws -> GraphQLResponse<Operation.Data> = GraphQLRequest<Operation>.defaultDecoder()
            ) async throws -> GraphQLResponse<Operation.Data>.Success {
                let (data, response) = try await data(for: request.urlRequest)
                if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                    throw HTTPError(response: httpResponse)
                }
                switch try decoder(data) {
                case .success(let success): return success
                case .requestError(let requestError): throw requestError
                }
            }\(subscriptions())
        }
        """
    }

    private func subscriptions() -> String {
        guard includeSubscriptionSupport else { return "" }
        return """

            
            /// Initiates an event stream using a GraphQL subscription.
            /// This implementation assumes your server uses the "GraphQL over Server-Sent Events" spec:
            /// https://github.com/graphql/graphql-over-http/blob/main/rfcs/GraphQLOverSSE.md#distinct-connections-mode
            /// - Parameters:
            ///   - request: The  request containing the `URLRequest` to be performed. The `URLRequest` must have `text/event-stream` set
            ///   in the "accept" header.
            ///   - decoder: The function used to turn response data into an Subscription.Data instance.
            public func subscribe<Subscription: GraphQLSubscription>(
                _ request: GraphQLRequest<Subscription>,
                decoder: @escaping @Sendable (Data) throws -> GraphQLResponse<Subscription.Data> = GraphQLRequest<Subscription>.defaultDecoder()
            ) async throws -> AsyncThrowingStream<GraphQLResponse<Subscription.Data>.Success, Error> {
                let (asyncBytes, response) = try await bytes(for: request.urlRequest)
                if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                    throw HTTPError(response: httpResponse)
                }
                return AsyncThrowingStream { continuation in
                    let task = Task {
                        var buffer = ServerSentEventBuffer()
                        for try await byte in asyncBytes {
                            if let messageData = buffer.append(byte) {
                                switch try decoder(messageData) {
                                case .success(let success): continuation.yield(success)
                                case .requestError(let requestError): throw requestError
                                }
                            }
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in
                        task.cancel()
                    }
                }
            }

            private struct ServerSentEventBuffer {
                private let newline: UInt8 = 0x0A
                private let colon: UInt8 = 0x3A
                private let space: UInt8 = 0x20
                private let dataKey = Array("data".utf8)
                private var buffer: [UInt8] = []
                mutating func append(_ byte: UInt8) -> Data? {
                    buffer.append(byte)
                    guard let range = buffer.lastRange(of: [newline, newline]) else { return nil }
                    let messageData = buffer[..<range.lowerBound]
                    buffer.removeSubrange(..<range.upperBound)
                    let lines = messageData.split(separator: newline)
                    for line in lines where !line.isEmpty {
                        let parts = line.split(separator: colon, maxSplits: 1)
                        switch parts.count {
                        case 1: return Data(parts[0].trimmingPrefix([space]))
                        case 2:
                            if Array(parts[0]) == dataKey {
                                return Data(parts[1].trimmingPrefix([space]))
                            }
                        default: break
                        }
                    }
                    return nil
                }
            }
        """
    }
}
