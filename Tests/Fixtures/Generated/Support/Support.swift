// @generated
import CryptoKit
import Foundation

struct AnyEncodable: Encodable, Sendable {
    private let encoder: @Sendable (Encoder) throws -> Void
    init<T: Encodable & Sendable>(_ value: T) {
        self.encoder = { encoder in try value.encode(to: encoder) }
    }
    init?<T: Encodable & Sendable>(_ value: T?) {
        guard let value else { return nil }
        self.encoder = { encoder in try value.encode(to: encoder) }
    }
    func encode(to encoder: Encoder) throws {
        try self.encoder(encoder)
    }
}

enum GraphQLEnum<T>: Decodable, Hashable, Sendable where T: Hashable & RawRepresentable & Sendable, T.RawValue == String {
    case known(T)
    case unknown(String)

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        if let value = T(rawValue: rawValue) {
            self = .known(value)
        } else {
            self = .unknown(rawValue)
        }
    }
}

/// https://spec.graphql.org/September2025/#sec-Errors
struct GraphQLError: Decodable, Sendable {
    struct Location: Decodable, Sendable {
        let line: Int
        let column: Int
    }

    enum PathSegment: Decodable, Sendable {
        case listIndex(Int)
        case field(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let stringValue = try? container.decode(String.self) {
                self = .field(stringValue)
            } else if let intValue = try? container.decode(Int.self), intValue >= 0 {
                self = .listIndex(intValue)
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: """
                    Path segments that represent fields should be strings, and path segments that represent list indices should be non-negative integers.
                    https://spec.graphql.org/September2025/#sec-Response-Position
                    """
                )
            }
        }
    }

    let message: String
    let locations: [Location]?
    let path: [PathSegment]?
    let extensions: [String: JSONValue]?
}

enum GraphQLHasDefault<T>: Encodable, Hashable, Sendable where T: Encodable & Hashable & Sendable {
    case useDefault
    case value(T)

    func encode(to encoder: Encoder) throws {
        switch self {
        case .useDefault:
            throw EncodingError.invalidValue(
                self,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "GraphQLHasDefault.useDefault must be encoded from a keyed container."
                )
            )
        case .value(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        }
    }
}

extension KeyedEncodingContainer {
    mutating func encode<T>(
        _ value: GraphQLHasDefault<T>,
        forKey key: Key
    ) throws where T: Encodable & Hashable & Sendable {
        switch value {
        case .useDefault: break
        case .value(let value): try encode(value, forKey: key)
        }
    }
}

enum GraphQLNullable<T>: Encodable, Hashable, Sendable where T: Encodable & Hashable & Sendable {
    case null
    case value(T)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .value(let t): try container.encode(t)
        }
    }
}

enum GraphQLResponse<Data>: Decodable where Data: Decodable, Data: Sendable {
    struct ExecutionResult: Sendable {
        let data: Data?
        let errors: [GraphQLError]?
        let extensions: [String: JSONValue]?
    }

    struct RequestError: Error, Sendable {
        let errors: [GraphQLError]
        let extensions: [String: JSONValue]?
    }

    case executionResult(ExecutionResult)
    case requestError(RequestError)

    private enum CodingKeys: String, CodingKey {
        case data
        case errors
        case extensions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let errors = try container.decodeIfPresent([GraphQLError].self, forKey: .errors)
        let extensions = try container.decodeIfPresent([String: JSONValue].self, forKey: .extensions)
        if container.contains(.data) {
            let data = try container.decodeIfPresent(Data.self, forKey: .data)
            guard errors?.isEmpty != true else {
                throw DecodingError.dataCorruptedError(
                    forKey: .errors,
                    in: container,
                    debugDescription: """
                    The errors entry in the response is a non-empty list of errors
                    https://spec.graphql.org/September2025/#sec-Execution-Result
                    """
                )
            }
            self = .executionResult(
                GraphQLResponse<Data>.ExecutionResult(
                    data: data,
                    errors: errors,
                    extensions: extensions
                )
            )
        } else {
            guard let errors, !errors.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .errors,
                    in: container,
                    debugDescription: """
                    If the data entry in the response is not present, the errors entry in the response must not be empty
                    https://spec.graphql.org/September2025/#sec-Request-Error-Result
                    """
                )
            }
            self = .requestError(RequestError(errors: errors, extensions: extensions))
        }
    }
}

enum JSONValue: Decodable, Sendable {
    case map([String: JSONValue])
    case list([JSONValue])
    case null
    case string(String)
    case number(Double)
    case boolean(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .number(doubleValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .boolean(boolValue)
        } else if let arrayValue = try? container.decode([JSONValue].self) {
            self = .list(arrayValue)
        } else if let dictionaryValue = try? container.decode([String: JSONValue].self) {
            self = .map(dictionaryValue)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }
}

/// A URLQueryEncoder that encodes an operation into `URLEncodedQueryItem`s
/// using the spec described at:
/// https://graphql.github.io/graphql-over-http/draft/#sec-GET
struct DefaultURLQueryEncoder: URLQueryEncoder {
    private let jsonEncoder: JSONEncoder

    init(jsonEncoder: JSONEncoder = JSONEncoder()) {
        self.jsonEncoder = jsonEncoder
    }

    func encode<Operation: GraphQLOperation>(
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

private extension [URLEncodedQueryItem] {
    static func from(_ body: Body, jsonEncoder: JSONEncoder) throws -> Self {
        var items = [URLEncodedQueryItem]()
        if let operationName = body.operationName {
            items.append(URLEncodedQueryItem(name: "operationName", value: operationName))
        }
        if let query = body.query {
            items.append(URLEncodedQueryItem(name: "query", value: query))
        }
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

/// A HTTPBodyEncoder that encodes an operation into json formatted data
/// as specified by the spec:
/// https://graphql.github.io/graphql-over-http/draft/#sec-POST
struct JSONBodyEncoder: HTTPBodyEncoder {
    private let jsonEncoder: JSONEncoder

    init(jsonEncoder: JSONEncoder = JSONEncoder()) {
        self.jsonEncoder = jsonEncoder
    }

    let contentType = "application/json"
    func encode<Operation: GraphQLOperation>(
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

/// A `GraphQLOperation` represents a GraphQL document containing a single operation.
protocol GraphQLOperation: Sendable {

    /// The optional name of the operation.
    /// https://spec.graphql.org/September2025/#sel-FAFTDCFABAADFCBAAD-zM
    static var operationName: String? { get }

    /// The executable string operated on by a GraphQL service, containing
    /// an operation definition and zero or more fragment definitions.
    /// https://spec.graphql.org/September2025/#sec-Document
    static var document: String { get }

    /// The parameterized variables to execute the operation with.
    /// https://spec.graphql.org/September2025/#sec-Language.Variables
    var variables: Variables { get }

    /// The operation's variables erased for request encoding.
    /// Variable-free operations return `nil` so request encoders omit them.
    var requestVariables: AnyEncodable? { get }

    /// Metadata associated with the operation to include in the request.
    var extensions: [String: AnyEncodable]? { get }

    associatedtype Variables: Encodable, Sendable
    associatedtype Data: Decodable, Sendable
}

extension GraphQLOperation {
    var requestVariables: AnyEncodable? {
        let requestVariables: AnyEncodable = AnyEncodable(variables)
        return requestVariables
    }
}

extension GraphQLOperation where Variables == Never? {
    var requestVariables: AnyEncodable? { nil }
}

/// A `GraphQLSingleResponseOperation` produces one response and can be executed with `URLSession.request`.
/// Queries and mutations have this capability; subscriptions produce a stream instead.
protocol GraphQLSingleResponseOperation: GraphQLOperation {}

protocol GraphQLQuery: GraphQLSingleResponseOperation {}

protocol GraphQLMutation: GraphQLSingleResponseOperation {}

protocol GraphQLSubscription: GraphQLOperation {}

/// A name-value pair encoded using `application/x-www-form-urlencoded` rules.
struct URLEncodedQueryItem: Sendable {
    /// The unencoded parameter name.
    let name: String

    /// The unencoded parameter value.
    let value: String

    init(name: String, value: String) {
        self.name = name
        self.value = value
    }

    var percentEncoded: String {
        let allowedCharacters = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789*-._"
        )
        let name = name.addingPercentEncoding(withAllowedCharacters: allowedCharacters)!
        let value = value.addingPercentEncoding(withAllowedCharacters: allowedCharacters)!
        return (name + "=" + value).replacingOccurrences(of: "%20", with: "+")
    }
}

/// A `URLQueryEncoder` converts a GraphQL operation into `URLEncodedQueryItem`s for a GET request.
protocol URLQueryEncoder {

    /// Encodes an operation for a GET request.
    /// - Parameters:
    ///   operation: The operation to encode.
    ///   automaticPersistedOperationPhase: The request phase of the automatic persisted operation.
    ///   Pass a `nil` value to indicate persisted operations are not enabled and the operation document
    ///   should always be sent.
    /// - Returns: An array of `URLEncodedQueryItem`s to be used as the URL's query component.
    func encode<Operation: GraphQLOperation>(
        operation: Operation,
        automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?
    ) throws -> [URLEncodedQueryItem]
}

/// A `HTTPBodyEncoder` converts a GraphQL operation into the data to be set as the HTTP body
/// of a POST request.
protocol HTTPBodyEncoder {

    /// The value to set as the POST request's "content-type" header.
    var contentType: String { get }

    /// Encodes an operation into body data for a POST request.
    /// - Parameters:
    ///   operation: The GraphQL operation to encode.
    ///   automaticPersistedOperationPhase: The request phase of the automatic persisted operation.
    ///   Pass a `nil` value to indicate persisted operations are not enabled and the operation document
    ///   should always be sent.
    /// - Returns: The encoded data to be set as the HTTP body of the POST request.
    func encode<Operation: GraphQLOperation>(
        operation: Operation,
        automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?
    ) throws -> Data
}

/// Indicates which phase of Automatic Persisted Operations the request is for.
enum AutomaticPersistedOperationPhase {

    /// This phase indicates encoders should encode an operation's hash instead of the document
    /// text.
    case initialRequestWithHash

    /// This phase indicates encoders should encode an operation's document text as well as its hash, because
    /// the document's hash was not previously found by the server.
    case persistRequestWithDocument
}

/// Defaults conform to https://graphql.github.io/graphql-over-http/draft/
extension URLSession {
    enum HTTPError: Error {
        case invalidType(URLResponse)
        case invalidContentType(String?)
        case badResponse(HTTPURLResponse, Data?)
    }

    /// Executes a single-response GraphQL operation.
    /// - Parameters:
    ///   - request: The request containing the `URLRequest` to be performed.
    ///   - decoder: The function used to decode response data for the operation.
    func request<Operation: GraphQLSingleResponseOperation>(
        _ request: GraphQLRequest<Operation>,
        decoder: (Operation, Data) throws -> GraphQLResponse<Operation.Data> = GraphQLRequest<Operation>.defaultDecoder
    ) async throws -> GraphQLResponse<Operation.Data>.ExecutionResult {
        let (data, response) = try await data(for: request.urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidType(response)
        }
        let contentType = httpResponse.value(forHTTPHeaderField: "content-type")
        let mediaType = contentType?.split(separator: ";", maxSplits: 1).first.map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        let isGraphQLResponse = mediaType?.caseInsensitiveCompare(
            "application/graphql-response+json"
        ) == .orderedSame
        let isJSONResponse = mediaType?.caseInsensitiveCompare("application/json") == .orderedSame
        guard isGraphQLResponse || isJSONResponse else {
            throw HTTPError.invalidContentType(contentType)
        }
        guard isGraphQLResponse || (200..<300).contains(httpResponse.statusCode) else {
            throw HTTPError.badResponse(httpResponse, data)
        }
        switch try decoder(request.operation, data) {
        case .executionResult(let executionResult): return executionResult
        case .requestError(let requestError):
            let containsPersistedQueryNotFound = requestError.errors.contains { error in
                if case .string("PERSISTED_QUERY_NOT_FOUND")? = error.extensions?["code"] {
                    return true
                }
                return error.message == "PersistedQueryNotFound"
            }
            if containsPersistedQueryNotFound,
               let retry = request.persistedOperationRetry {
                return try await self.request(
                    try request.updated(for: retry),
                    decoder: decoder
                )
            }
            throw requestError
        }
    }

    enum SubscriptionError: Error {
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
    /// https://github.com/graphql/graphql-over-http/blob/main/rfcs/GraphQLOverSSE.md#distinct-connections-mode
    /// - Important: Automatic persisted operations are not supported for subscriptions. Subscription
    /// requests always include the full operation document.
    ///
    /// Lines, complete event payloads, and decoded results waiting for the consumer are bounded independently.
    /// - Important: This API requires version 26 or newer of macOS, iOS, tvOS, watchOS, or visionOS.
    /// - Parameters:
    ///   - request: The request containing the `URLRequest` to be performed. The `URLRequest` must have
    ///   `text/event-stream` set in the "accept" header.
    ///   - decoder: The function used to decode response data for the subscription.
    ///   - maximumEventByteCount: The largest combined payload allowed across an event's `data` fields.
    ///   - maximumLineByteCount: The largest SSE line allowed, excluding its terminator. The default provides
    ///   framing headroom beyond `maximumEventByteCount` for a payload sent on one `data` line.
    ///   - maximumBufferedResultCount: The number of decoded results that may wait for the stream consumer.
    func subscribe<Subscription: GraphQLSubscription>(
        _ request: GraphQLRequest<Subscription>,
        decoder: @escaping @Sendable (Subscription, Data) throws -> GraphQLResponse<Subscription.Data> = GraphQLRequest<Subscription>.defaultDecoder,
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
        let operation = request.operation
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
                            switch try decoder(operation, event.data) {
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
                            case .requestError(let requestError):
                                // TODO: Support automatic persisted operation fallback for subscriptions.
                                throw requestError
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
}

private extension URL {
    func appending(queryItems: [URLEncodedQueryItem]) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        let percentEncodedQuery = queryItems.map(\.percentEncoded).joined(separator: "&")
        if let existingQuery = components.percentEncodedQuery, !existingQuery.isEmpty {
            components.percentEncodedQuery = existingQuery + "&" + percentEncodedQuery
        } else {
            components.percentEncodedQuery = percentEncodedQuery
        }
        return components.url!
    }
}

enum PersistedOperationRetry {
    case GET(queryEncoder: URLQueryEncoder)
    case POST(bodyEncoder: HTTPBodyEncoder)
}

/// A `GraphQLRequest` represents a `URLRequest` for a GraphQL operation.
struct GraphQLRequest<Operation: GraphQLOperation> {

    /// The `URLRequest` used to execute a GraphQL request. Callers may mutate this property
    /// after initialization to set authorization headers, timeouts, and other request options.
    var urlRequest: URLRequest

    /// The GraphQL endpoint the request will be made to.
    let endpoint: URL

    /// The GraphQL operation executed in the request.
    let operation: Operation
    /// The retry configuration for an unknown persisted operation.
    let persistedOperationRetry: PersistedOperationRetry?

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
}

extension GraphQLRequest {
    /// The decoding function used by default for an operation and its GraphQL response.
    static var defaultDecoder: @Sendable (Operation, Data) throws -> GraphQLResponse<Operation.Data> {
        { _, data in try JSONDecoder().decode(GraphQLResponse<Operation.Data>.self, from: data) }
    }

    /// Returns a request updated to retry an unknown persisted operation with its full document.
    func updated(
        for retry: PersistedOperationRetry
    ) throws -> Self where Operation: GraphQLSingleResponseOperation {
        var urlRequest = urlRequest
        switch retry {
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

    /// Describes how the `GraphQLRequest` should encode a `GraphQLQuery` operation into its `URLRequest`
    enum QueryStrategy {

        /// Describes how to retry an automatic persisted operation when its hash is not recognized.
        enum AutomaticPersistedOperationRetryPolicy {

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
    init(
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

    /// Initializes a POST request for a single-response GraphQL operation.
    init(
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

    /// Describes how the `GraphQLRequest` should encode a `GraphQLSubscription` operation into its
    /// `URLRequest`.
    enum SubscriptionStrategy {

        /// Instructs the request to be a GET request.
        case GET(queryEncoder: URLQueryEncoder = DefaultURLQueryEncoder())

        /// Instructs the request to be a POST request.
        case POST(bodyEncoder: HTTPBodyEncoder = JSONBodyEncoder())
    }

    /// Initializes a new `GraphQLRequest` with a subscription operation
    /// - Parameters:
    ///   - subscription: The GraphQLSubscription operation the request is for.
    ///   - endpoint: The GraphQL server endpoint supporting GraphQL over Server-Sent Events.
    ///   - strategy: The option describing whether the request should be a GET or POST. `GET` by default.
    ///   Automatic persisted operations are unavailable because subscription fallback is not supported.
    init(
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
}
