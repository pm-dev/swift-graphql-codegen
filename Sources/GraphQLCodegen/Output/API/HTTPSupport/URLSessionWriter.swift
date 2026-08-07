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

    func write(using fileOutput: FileOutput) async throws {
        try await content().write(to: url, using: fileOutput)
    }

    private func content() -> String {
        """
        \(header)import Foundation

        /// Defaults conform to https://graphql.github.io/graphql-over-http/draft/
        extension URLSession {
            \(accessLevel)struct HTTPError: Error {
                \(accessLevel)let response: HTTPURLResponse
            }

            /// Executes a single-response GraphQL operation.
            /// - Parameters:
            ///   - request: The request containing the `URLRequest` to be performed.
            ///   - decoder: The function used to turn response data into an Operation.Data instance.
            \(accessLevel)func request<Operation: GraphQLSingleResponseOperation>(
                _ request: GraphQLRequest<Operation>,
                decoder: (Data) throws -> GraphQLResponse<Operation.Data> = GraphQLRequest<Operation>.defaultDecoder
            ) async throws -> GraphQLResponse<Operation.Data>.Success {
                let (data, response) = try await data(for: request.urlRequest)
                if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                    throw HTTPError(response: httpResponse)
                }
                switch try decoder(data) {
                case .success(let success): return success
                \(requestErrorHandling())
                }
            }\(subscriptions())
        }
        """
    }

    private func requestErrorHandling() -> String {
        switch configuration.output.documents.operations.persistedOperations {
        case .automatic:
            """
            case .requestError(let requestError):
                        let containsPersistedQueryNotFound = requestError.errors.contains { error in
                            error.message == "PersistedQueryNotFound"
                        }
                        if containsPersistedQueryNotFound,
                           let retry = request.persistedOperationRetry {
                            return try await self.request(
                                try request.updated(for: retry),
                                decoder: decoder
                            )
                        }
                        throw requestError
            """
        case .registered, .none:
            "case .requestError(let requestError): throw requestError"
        }
    }

    private func subscriptions() -> String {
        guard includeSubscriptionSupport else { return "" }
        return """


            \(accessLevel)enum SubscriptionError: Error {
                case eventTooLarge(maximumByteCount: Int)
                case invalidContentType(String?)
                case invalidMaximumBufferedResultCount(Int)
                case invalidMaximumEventByteCount(Int)
                case invalidUTF8
                case missingCompleteEvent
                case resultBufferOverflow(maximumBufferedResultCount: Int)
            }

            /// Initiates an event stream using a GraphQL subscription.
            /// This implementation assumes your server uses the "GraphQL over Server-Sent Events" spec:
            /// https://github.com/graphql/graphql-over-http/blob/main/rfcs/GraphQLOverSSE.md#distinct-connections-mode\(automaticPersistedOperationSubscriptionDocumentation())
            ///
            /// Only use this API with a trusted GraphQL server. The parser buffers input until it encounters an SSE line
            /// terminator, so the server must not send an arbitrarily long unterminated line. Complete events and queued
            /// results remain bounded by `maximumEventByteCount` and `maximumBufferedResultCount`, respectively.
            /// - Parameters:
            ///   - request: The request containing the `URLRequest` to be performed. The `URLRequest` must have
            ///   `text/event-stream` set in the "accept" header.
            ///   - decoder: The function used to turn response data into a Subscription.Data instance.
            ///   - maximumEventByteCount: The largest combined payload allowed across an event's `data` fields.
            ///   - maximumBufferedResultCount: The number of decoded results that may wait for the stream consumer.
            \(accessLevel)func subscribe<Subscription: GraphQLSubscription>(
                _ request: GraphQLRequest<Subscription>,
                decoder: @escaping @Sendable (Data) throws -> GraphQLResponse<Subscription.Data> = GraphQLRequest<Subscription>.defaultDecoder,
                maximumEventByteCount: Int = 1_048_576,
                maximumBufferedResultCount: Int = 16
            ) async throws -> AsyncThrowingStream<GraphQLResponse<Subscription.Data>.Success, Error> {
                guard maximumEventByteCount > 0 else {
                    throw SubscriptionError.invalidMaximumEventByteCount(maximumEventByteCount)
                }
                guard maximumBufferedResultCount > 0 else {
                    throw SubscriptionError.invalidMaximumBufferedResultCount(maximumBufferedResultCount)
                }
                let (asyncBytes, response) = try await bytes(for: request.urlRequest)
                if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                    throw HTTPError(response: httpResponse)
                }
                guard response.mimeType?.caseInsensitiveCompare("text/event-stream") == .orderedSame else {
                    throw SubscriptionError.invalidContentType(response.mimeType)
                }
                return AsyncThrowingStream(
                    bufferingPolicy: .bufferingOldest(maximumBufferedResultCount)
                ) { continuation in
                    let task = Task {
                        do {
                            var accumulator = ServerSentEventAccumulator()
                            var lineBuffer = ServerSentEventLineBuffer()
                            for try await byte in asyncBytes {
                                guard let line = try lineBuffer.append(byte) else { continue }
                                guard let event = try accumulator.consume(
                                    line,
                                    maximumByteCount: maximumEventByteCount
                                ) else { continue }
                                switch event.name {
                                case "next":
                                    switch try decoder(event.data) {
                                    case .success(let success):
                                        switch continuation.yield(success) {
                                        case .enqueued: break
                                        case .dropped:
                                            throw SubscriptionError.resultBufferOverflow(
                                                maximumBufferedResultCount: maximumBufferedResultCount
                                            )
                                        case .terminated: return
                                        @unknown default: return
                                        }
                                    \(subscriptionRequestErrorHandling())
                                }
                                case "complete":
                                    continuation.finish()
                                    return
                                default: continue
                                }
                            }
                            throw SubscriptionError.missingCompleteEvent
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                    continuation.onTermination = { _ in
                        task.cancel()
                    }
                }
            }

            private struct ServerSentEvent {
                let data: Data
                let name: String
            }

            private struct ServerSentEventAccumulator {
                private var data = Data()
                private var hasDataField = false
                private var isFirstLine = true
                private var name = "message"

                mutating func consume(
                    _ line: String,
                    maximumByteCount: Int
                ) throws -> ServerSentEvent? {
                    var line = line
                    if isFirstLine {
                        isFirstLine = false
                        if line.first == "\\u{FEFF}" {
                            line.removeFirst()
                        }
                    }
                    guard !line.isEmpty else {
                        defer { reset() }
                        guard hasDataField else { return nil }
                        return ServerSentEvent(data: data, name: name)
                    }
                    guard !line.hasPrefix(":") else { return nil }

                    let field: Substring
                    let value: Substring
                    if let colonIndex = line.firstIndex(of: ":") {
                        field = line[..<colonIndex]
                        let valueStartIndex = line.index(after: colonIndex)
                        let untrimmedValue = line[valueStartIndex...]
                        value = untrimmedValue.first == " " ? untrimmedValue.dropFirst() : untrimmedValue
                    } else {
                        field = line[...]
                        value = line[line.endIndex...]
                    }

                    switch field {
                    case "data":
                        let separatorByteCount = hasDataField ? 1 : 0
                        guard data.count <= maximumByteCount - separatorByteCount else {
                            throw SubscriptionError.eventTooLarge(maximumByteCount: maximumByteCount)
                        }
                        let remainingByteCount = maximumByteCount - separatorByteCount - data.count
                        guard value.utf8.count <= remainingByteCount else {
                            throw SubscriptionError.eventTooLarge(maximumByteCount: maximumByteCount)
                        }
                        if hasDataField {
                            data.append(0x0A)
                        }
                        data.append(contentsOf: value.utf8)
                        hasDataField = true
                    case "event":
                        name = String(value)
                    default: break
                    }
                    return nil
                }

                private mutating func reset() {
                    data.removeAll(keepingCapacity: true)
                    hasDataField = false
                    name = "message"
                }
            }

            /// Preserves empty lines because Foundation's `AsyncLineSequence` omits them and SSE uses them as event
            /// delimiters.
            private struct ServerSentEventLineBuffer {
                private let carriageReturn: UInt8 = 0x0D
                private let lineFeed: UInt8 = 0x0A
                private var buffer: [UInt8] = []
                private var previousByteWasCarriageReturn = false

                mutating func append(_ byte: UInt8) throws -> String? {
                    if byte == lineFeed {
                        if previousByteWasCarriageReturn {
                            previousByteWasCarriageReturn = false
                            return nil
                        }
                        return try takeLine()
                    }
                    previousByteWasCarriageReturn = false
                    if byte == carriageReturn {
                        previousByteWasCarriageReturn = true
                        return try takeLine()
                    }
                    buffer.append(byte)
                    return nil
                }

                private mutating func takeLine() throws -> String {
                    defer { buffer.removeAll(keepingCapacity: true) }
                    guard let line = String(bytes: buffer, encoding: .utf8) else {
                        throw SubscriptionError.invalidUTF8
                    }
                    return line
                }
            }
        """
    }

    private func automaticPersistedOperationSubscriptionDocumentation() -> String {
        guard case .automatic = configuration.output.documents.operations.persistedOperations else { return "" }
        return """

            /// - Important: Automatic persisted operations are not supported for subscriptions. Subscription
            /// requests always include the full operation document.
        """
    }

    private func subscriptionRequestErrorHandling() -> String {
        switch configuration.output.documents.operations.persistedOperations {
        case .automatic:
            """
            case .requestError(let requestError):
                                            // TODO: Support automatic persisted operation fallback for subscriptions.
                                            throw requestError
            """
        case .registered, .none:
            "case .requestError(let requestError): throw requestError"
        }
    }
}
