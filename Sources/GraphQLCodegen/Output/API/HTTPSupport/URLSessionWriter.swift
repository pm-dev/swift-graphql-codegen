import Foundation

struct URLSessionWriter: APIOutput {
    let hasSubscription: Bool
    let configuration: Configuration
    let relativePath = "HTTPSupport/URLSession+GraphQL.swift"

    let topLevelTypeNames: [SwiftTypeIdentifier] = []

    private var includeSubscriptionSupport: Bool {
        hasSubscription && configuration.output.api.HTTPSupport?.subscriptionSupport == true
    }

    var source: String {
        """
        \(headerBeforeImports)import Foundation

        /// Defaults conform to https://graphql.github.io/graphql-over-http/draft/
        extension URLSession {
            \(accessLevel)enum HTTPError: Error {
                case invalidType(URLResponse)
                case badResponse(HTTPURLResponse, Data?)
            }

            /// Executes a single-response GraphQL operation.
            /// - Parameters:
            ///   - request: The request containing the `URLRequest` to be performed.
            ///   - decoder: The function used to turn response data into an Operation.Data instance.
            \(accessLevel)func request<Operation: GraphQLSingleResponseOperation>(
                _ request: GraphQLRequest<Operation>,
                decoder: (Data) throws -> GraphQLResponse<Operation.Data> = GraphQLRequest<Operation>.defaultDecoder
            ) async throws -> GraphQLResponse<Operation.Data>.ExecutionResult {
                let (data, response) = try await data(for: request.urlRequest)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw HTTPError.invalidType(response)
                }
                guard
                    (200..<300).contains(httpResponse.statusCode) ||
                    httpResponse.mimeType?.caseInsensitiveCompare(
                        \"application/graphql-response+json\"
                    ) == .orderedSame
                else {
                    throw HTTPError.badResponse(httpResponse, data)
                }
                switch try decoder(data) {
                case .executionResult(let executionResult): return executionResult
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
                case invalidMaximumLineByteCount(Int)
                case invalidUTF8
                case lineTooLarge(maximumByteCount: Int)
                case missingCompleteEvent
                case resultBufferOverflow(maximumBufferedResultCount: Int)
            }

            /// Initiates an event stream using a GraphQL subscription.
            /// This implementation assumes your server uses the "GraphQL over Server-Sent Events" spec:
            /// https://github.com/graphql/graphql-over-http/blob/main/rfcs/GraphQLOverSSE.md#distinct-connections-mode\(automaticPersistedOperationSubscriptionDocumentation())
            ///
            /// Lines, complete event payloads, and decoded results waiting for the consumer are bounded independently.
            /// - Important: This API requires version 26 or newer of macOS, iOS, tvOS, watchOS, or visionOS.
            /// - Parameters:
            ///   - request: The request containing the `URLRequest` to be performed. The `URLRequest` must have
            ///   `text/event-stream` set in the "accept" header.
            ///   - decoder: The function used to turn response data into a Subscription.Data instance.
            ///   - maximumEventByteCount: The largest combined payload allowed across an event's `data` fields.
            ///   - maximumLineByteCount: The largest SSE line allowed, excluding its terminator. The default provides
            ///   framing headroom beyond `maximumEventByteCount` for a payload sent on one `data` line.
            ///   - maximumBufferedResultCount: The number of decoded results that may wait for the stream consumer.
            \(accessLevel)func subscribe<Subscription: GraphQLSubscription>(
                _ request: GraphQLRequest<Subscription>,
                decoder: @escaping @Sendable (Data) throws -> GraphQLResponse<Subscription.Data> = GraphQLRequest<Subscription>.defaultDecoder,
                maximumEventByteCount: Int = 1_048_576,
                maximumLineByteCount: Int = 1_052_672,
                maximumBufferedResultCount: Int = 16
            ) async throws -> AsyncThrowingStream<GraphQLResponse<Subscription.Data>.ExecutionResult, Error> {
                guard maximumEventByteCount > 0 else {
                    throw SubscriptionError.invalidMaximumEventByteCount(maximumEventByteCount)
                }
                guard maximumLineByteCount > 0 else {
                    throw SubscriptionError.invalidMaximumLineByteCount(maximumLineByteCount)
                }
                guard maximumBufferedResultCount > 0 else {
                    throw SubscriptionError.invalidMaximumBufferedResultCount(maximumBufferedResultCount)
                }
                let (asyncBytes, response) = try await bytes(for: request.urlRequest)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw HTTPError.invalidType(response)
                }
                guard (200..<300).contains(httpResponse.statusCode) else {
                    throw HTTPError.badResponse(httpResponse, nil)
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
                            var lineBuffer = ServerSentEventLineBuffer(
                                maximumByteCount: maximumLineByteCount
                            )
                            for try await byte in asyncBytes {
                                guard try lineBuffer.append(byte) else { continue }
                                let event = try lineBuffer.consumeLine { line in
                                    try accumulator.consume(
                                        line,
                                        maximumByteCount: maximumEventByteCount
                                    )
                                }
                                guard let event else { continue }
                                switch event.name {
                                case .next:
                                    switch try decoder(event.data) {
                                    case .executionResult(let executionResult):
                                        switch continuation.yield(executionResult) {
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
                                case .complete:
                                    continuation.finish()
                                    return
                                case .other: continue
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
                let name: ServerSentEventName
            }

            private enum ServerSentEventName {
                case complete
                case next
                case other
            }

            private struct ServerSentEventAccumulator {
                private let colon: UInt8 = 0x3A
                private let dataFieldSeparator: UInt8 = 0x0A
                private let space: UInt8 = 0x20
                private var data = Data()
                private var hasDataField = false
                private var isFirstLine = true
                private var name = ServerSentEventName.other

                mutating func consume(
                    _ line: UTF8Span,
                    maximumByteCount: Int
                ) throws -> ServerSentEvent? {
                    var bytes = line.span
                    if isFirstLine {
                        isFirstLine = false
                        if startsWithByteOrderMark(bytes) {
                            bytes = bytes.extracting(droppingFirst: 3)
                        }
                    }
                    guard !bytes.isEmpty else {
                        defer { reset() }
                        guard hasDataField || name == .complete else { return nil }
                        return ServerSentEvent(data: data, name: name)
                    }
                    guard bytes[0] != colon else { return nil }

                    let field: Span<UInt8>
                    let value: Span<UInt8>
                    if let colonIndex = bytes.indices.first(where: { bytes[$0] == colon }) {
                        field = bytes.extracting(0..<colonIndex)
                        var valueStartIndex = colonIndex + 1
                        if valueStartIndex < bytes.count, bytes[valueStartIndex] == space {
                            valueStartIndex += 1
                        }
                        value = bytes.extracting(valueStartIndex..<bytes.count)
                    } else {
                        field = bytes
                        value = bytes.extracting(bytes.count..<bytes.count)
                    }

                    if matches(field, "data".utf8) {
                        let separatorByteCount = hasDataField ? 1 : 0
                        guard data.count <= maximumByteCount - separatorByteCount else {
                            throw SubscriptionError.eventTooLarge(maximumByteCount: maximumByteCount)
                        }
                        let remainingByteCount = maximumByteCount - separatorByteCount - data.count
                        guard value.count <= remainingByteCount else {
                            throw SubscriptionError.eventTooLarge(maximumByteCount: maximumByteCount)
                        }
                        if hasDataField {
                            data.append(dataFieldSeparator)
                        }
                        value.withUnsafeBufferPointer { buffer in
                            data.append(contentsOf: buffer)
                        }
                        hasDataField = true
                    } else if matches(field, "event".utf8) {
                        if matches(value, "complete".utf8) {
                            name = .complete
                        } else if matches(value, "next".utf8) {
                            name = .next
                        } else {
                            name = .other
                        }
                    }
                    return nil
                }

                private func matches(
                    _ bytes: Span<UInt8>,
                    _ expected: String.UTF8View
                ) -> Bool {
                    bytes.withUnsafeBufferPointer { buffer in
                        buffer.elementsEqual(expected)
                    }
                }

                private mutating func reset() {
                    data.removeAll(keepingCapacity: true)
                    hasDataField = false
                    name = .other
                }

                private func startsWithByteOrderMark(_ bytes: Span<UInt8>) -> Bool {
                    bytes.count >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF
                }
            }

            /// Preserves empty lines because Foundation's `AsyncLineSequence` omits them and SSE uses them as event
            /// delimiters.
            private struct ServerSentEventLineBuffer {
                private let carriageReturn: UInt8 = 0x0D
                private let lineFeed: UInt8 = 0x0A
                private let maximumByteCount: Int
                private var buffer: [UInt8] = []
                private var previousByteWasCarriageReturn = false

                init(maximumByteCount: Int) {
                    self.maximumByteCount = maximumByteCount
                }

                mutating func append(_ byte: UInt8) throws -> Bool {
                    if byte == lineFeed {
                        if previousByteWasCarriageReturn {
                            previousByteWasCarriageReturn = false
                            return false
                        }
                        return true
                    }
                    previousByteWasCarriageReturn = false
                    if byte == carriageReturn {
                        previousByteWasCarriageReturn = true
                        return true
                    }
                    guard buffer.count < maximumByteCount else {
                        throw SubscriptionError.lineTooLarge(maximumByteCount: maximumByteCount)
                    }
                    buffer.append(byte)
                    return false
                }

                mutating func consumeLine<Result>(
                    _ body: (UTF8Span) throws -> Result
                ) throws -> Result {
                    defer { buffer.removeAll(keepingCapacity: true) }
                    let line: UTF8Span
                    do {
                        line = try UTF8Span(validating: buffer.span)
                    } catch {
                        throw SubscriptionError.invalidUTF8
                    }
                    return try body(line)
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
