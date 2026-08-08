import Dispatch
import Foundation
@testable import StarwarsExample
import Testing

struct ServerSentEventTests {
    @Test
    func parsesStandardsCompliantEventsAndCompletes() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        let stream = try await session.subscribe(try makeRequest(path: "standards"))
        var values: [GraphQLEnum<Episode>] = []
        for try await response in stream {
            values.append(response.data.favoriteEpisodeChanged)
        }

        #expect(values == [.known(.jedi)])
    }

    @Test
    func acceptsCompleteEventWithoutData() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        let stream = try await session.subscribe(try makeRequest(path: "complete-without-data"))
        var yieldedResult = false
        for try await _ in stream {
            yieldedResult = true
        }

        #expect(!yieldedResult)
    }

    @Test
    func rejectsStreamWithoutCompleteEvent() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        var rejected = false
        do {
            let stream = try await session.subscribe(try makeRequest(path: "missing-complete"))
            for try await _ in stream {}
        } catch URLSession.SubscriptionError.missingCompleteEvent {
            rejected = true
        }

        #expect(rejected)
    }

    @Test
    func rejectsOversizedEvent() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        var rejectedMaximumByteCount: Int?
        do {
            let stream = try await session.subscribe(
                try makeRequest(path: "oversized"),
                maximumEventByteCount: 8
            )
            for try await _ in stream {}
        } catch URLSession.SubscriptionError.eventTooLarge(let maximumByteCount) {
            rejectedMaximumByteCount = maximumByteCount
        }

        #expect(rejectedMaximumByteCount == 8)
    }

    @Test
    func rejectsOversizedLine() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        var rejectedMaximumByteCount: Int?
        do {
            let stream = try await session.subscribe(
                try makeRequest(path: "oversized-line"),
                maximumLineByteCount: 8
            )
            for try await _ in stream {}
        } catch URLSession.SubscriptionError.lineTooLarge(let maximumByteCount) {
            rejectedMaximumByteCount = maximumByteCount
        }

        #expect(rejectedMaximumByteCount == 8)
    }

    @Test
    func acceptsMaximumLineSize() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        let stream = try await session.subscribe(
            try makeRequest(path: "maximum-line"),
            maximumLineByteCount: 15
        )
        var yieldedResult = false
        for try await _ in stream {
            yieldedResult = true
        }

        #expect(!yieldedResult)
    }

    @Test
    func rejectsInvalidMaximumLineSize() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        var rejectedMaximumByteCount: Int?
        do {
            _ = try await session.subscribe(
                try makeRequest(path: "unused"),
                maximumLineByteCount: 0
            )
        } catch URLSession.SubscriptionError.invalidMaximumLineByteCount(let maximumByteCount) {
            rejectedMaximumByteCount = maximumByteCount
        }

        #expect(rejectedMaximumByteCount == 0)
    }

    @Test
    func rejectsInvalidUTF8() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        var rejected = false
        do {
            let stream = try await session.subscribe(try makeRequest(path: "invalid-utf8"))
            for try await _ in stream {}
        } catch URLSession.SubscriptionError.invalidUTF8 {
            rejected = true
        }

        #expect(rejected)
    }

    @Test
    func rejectsResultBufferOverflow() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        let secondResultDecoded = DispatchSemaphore(value: 0)
        let request = try GraphQLRequest(
            subscription: OverflowProbeSubscription(),
            endpoint: URL(string: "https://subscriptions.test/overflow")!
        )
        let stream = try await session.subscribe(
            request,
            decoder: { data in
                let text = try #require(String(bytes: data, encoding: .utf8))
                if text.contains("EMPIRE") {
                    secondResultDecoded.signal()
                }
                return .success(
                    GraphQLResponse<OverflowProbeData>.Success(
                        data: OverflowProbeData(),
                        fieldErrors: nil,
                        extensions: nil
                    )
                )
            },
            maximumBufferedResultCount: 1
        )
        let secondResultWasDecoded = await waitForSignal(secondResultDecoded)
        try #require(secondResultWasDecoded)
        // Give the subscription producer a turn to yield the decoded result before consumption begins.
        await Task.yield()

        var rejectedMaximumBufferedResultCount: Int?
        do {
            for try await _ in stream {}
        } catch URLSession.SubscriptionError.resultBufferOverflow(let maximumBufferedResultCount) {
            rejectedMaximumBufferedResultCount = maximumBufferedResultCount
        }

        #expect(rejectedMaximumBufferedResultCount == 1)
    }

    private func makeRequest(path: String) throws -> GraphQLRequest<FavoriteEpisodeChangedSubscription> {
        try GraphQLRequest(
            subscription: FavoriteEpisodeChangedSubscription(),
            endpoint: URL(string: "https://subscriptions.test/\(path)")!
        )
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SubscriptionURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func waitForSignal(_ semaphore: DispatchSemaphore) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let result = semaphore.wait(timeout: .now() + 30)
                continuation.resume(returning: result == .success)
            }
        }
    }
}

private final class SubscriptionURLProtocol: URLProtocol {
    // swiftlint:disable:next non_overridable_class_declaration static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    // swiftlint:disable:next non_overridable_class_declaration static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let body: Data
        switch url.path {
        case "/standards":
            body = Data(
                (
                    "\u{FEFF}event: next\r\n" +
                        "data: {\"data\":\r" +
                        "data: {\"favoriteEpisodeChanged\":\"JEDI\"}}\n\r\n" +
                        "event: complete\r" +
                        "data:\r\r"
                ).utf8
            )
        case "/complete-without-data":
            body = Data("event: complete\n\n".utf8)
        case "/missing-complete":
            body = Data("event: next\ndata: {\"data\":{\"favoriteEpisodeChanged\":\"JEDI\"}}\n\n".utf8)
        case "/oversized":
            body = Data("event: next\ndata: {\"data\":{\"favoriteEpisodeChanged\":\"EMPIRE\"}}\n\n".utf8)
        case "/oversized-line":
            body = Data(repeating: 0x61, count: 9)
        case "/maximum-line":
            body = Data(":12345678901234\r\nevent: complete\r\ndata:\r\n\r\n".utf8)
        case "/invalid-utf8":
            body = Data([0x3A, 0xC3, 0x28, 0x0A])
        case "/overflow":
            body = Data(
                (
                    "event: next\ndata: {\"data\":{\"favoriteEpisodeChanged\":\"JEDI\"}}\n\n" +
                        "event: next\ndata: {\"data\":{\"favoriteEpisodeChanged\":\"EMPIRE\"}}\n\n" +
                        "event: complete\ndata:\n\n"
                ).utf8
            )
        default:
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/event-stream"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private struct OverflowProbeData: Decodable, Sendable {}

private struct OverflowProbeSubscription: GraphQLSubscription {
    static let operationName: String? = "OverflowProbe"
    static let document = "subscription OverflowProbe { favoriteEpisodeChanged }"
    static let minifiedDocument = document

    let variables: Never? = nil
    let extensions: [String: StarwarsExample.AnyEncodable]? = nil

    typealias Data = OverflowProbeData
    typealias Variables = Never?
}
