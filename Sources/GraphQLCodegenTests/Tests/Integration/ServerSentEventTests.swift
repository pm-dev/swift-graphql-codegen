import Foundation
import GraphQLCodegen
import Testing

struct ServerSentEventTests {
    @Test
    func testGeneratedServerSentEventSupportPreservesCriticalInvariants() async throws {
        let generatedDirectory = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: generatedDirectory, withIntermediateDirectories: true)
        defer {
            // Best-effort test cleanup; retaining a temporary directory does not affect test behavior.
            try? FileManager.default.removeItem(at: generatedDirectory)
        }
        let schemaURL = generatedDirectory.appending(path: "schema.sdl", directoryHint: .notDirectory)
        try """
        schema {
          query: Query
          subscription: Subscription
        }

        type Query {
          value: String!
        }

        type Subscription {
          updates: String!
        }
        """.write(to: schemaURL, atomically: true, encoding: .utf8)
        let operationsDirectory = generatedDirectory.appending(path: "Operations", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: operationsDirectory, withIntermediateDirectories: true)
        try """
        subscription Updates {
          updates
        }
        """.write(
            to: operationsDirectory.appending(path: "Updates.graphql", directoryHint: .notDirectory),
            atomically: true,
            encoding: .utf8
        )
        let apiDirectory = generatedDirectory.appending(path: "API", directoryHint: .isDirectory)
        try await Codegen(
            .configuration(
                input: .input(
                    schemaSource: .SDLSchemaFile(schemaURL),
                    documentDirectories: [operationsDirectory]
                ),
                output: .output(
                    schema: .schema(
                        directory: generatedDirectory.appending(path: "SchemaTypes", directoryHint: .isDirectory)
                    ),
                    documents: .documents(directory: .directory(operationsDirectory)),
                    api: .api(
                        directory: apiDirectory,
                        HTTPSupport: .httpSupport(subscriptionSupport: true)
                    )
                )
            )
        ).run()

        let output = try String(
            contentsOf: apiDirectory.appending(
                path: "HTTPSupport/URLSession+GraphQL.swift",
                directoryHint: .notDirectory
            ),
            encoding: .utf8
        )
        #expect(output.contains("Only use this API with a trusted GraphQL server"))

        try #"""
        import Dispatch
        import Foundation

        final class SubscriptionURLProtocol: URLProtocol {
            override class func canInit(with request: URLRequest) -> Bool {
                true
            }

            override class func canonicalRequest(for request: URLRequest) -> URLRequest {
                request
            }

            override func startLoading() {
                guard let url = request.url else {
                    client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                    return
                }
                let body: String
                switch url.path {
                case "/standards":
                    body = "\u{FEFF}event: next\r\ndata: {\"data\":\rdata: {\"updates\":\"first\"}}\n\r\nevent: complete\rdata:\r\r"
                case "/missing-complete":
                    body = "event: next\ndata: {\"data\":{\"updates\":\"first\"}}\n\n"
                case "/oversized":
                    body = "event: next\ndata: {\"data\":{\"updates\":\"too large\"}}\n\n"
                case "/overflow":
                    body = "event: next\ndata: {\"data\":{\"updates\":\"first\"}}\n\nevent: next\ndata: {\"data\":{\"updates\":\"second\"}}\n\nevent: complete\ndata:\n\n"
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
                client?.urlProtocol(self, didLoad: Data(body.utf8))
                client?.urlProtocolDidFinishLoading(self)
            }

            override func stopLoading() {}
        }

        final class DroppedResultSignal: @unchecked Sendable {
            let semaphore: DispatchSemaphore

            init(semaphore: DispatchSemaphore) {
                self.semaphore = semaphore
            }

            deinit {
                semaphore.signal()
            }
        }

        final class OverflowProbeData: Decodable, @unchecked Sendable {
            let droppedResultSignal: DroppedResultSignal?

            init(droppedResultSignal: DroppedResultSignal?) {
                self.droppedResultSignal = droppedResultSignal
            }

            init(from decoder: Decoder) throws {
                droppedResultSignal = nil
            }
        }

        struct OverflowProbeSubscription: GraphQLSubscription {
            static let operationName: String? = "OverflowProbe"
            static let document = "subscription OverflowProbe { updates }"
            static let minifiedDocument = document

            let variables: Never? = nil
            let extensions: [String: AnyEncodable]? = nil

            typealias Data = OverflowProbeData
            typealias Variables = Never?
        }

        enum VerificationError: Error {
            case failed(String)
        }

        @main
        struct SubscriptionHarness {
            static func main() async throws {
                let harness = SubscriptionHarness()
                do {
                    try await harness.verifyStandardsParsingAndCompletion()
                } catch {
                    throw VerificationError.failed("Standards verification failed: \(error)")
                }
                do {
                    try await harness.verifyMissingCompletionFails()
                } catch {
                    throw VerificationError.failed("Completion verification failed: \(error)")
                }
                do {
                    try await harness.verifyEventSizeIsBounded()
                } catch {
                    throw VerificationError.failed("Event size verification failed: \(error)")
                }
                do {
                    try await harness.verifyResultBufferIsBounded()
                } catch {
                    throw VerificationError.failed("Result buffer verification failed: \(error)")
                }
            }

            private func makeRequest(path: String) throws -> GraphQLRequest<UpdatesSubscription> {
                try GraphQLRequest(
                    subscription: UpdatesSubscription(),
                    endpoint: URL(string: "https://subscriptions.test/\(path)")!
                )
            }

            private func makeSession() -> URLSession {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.protocolClasses = [SubscriptionURLProtocol.self]
                return URLSession(configuration: configuration)
            }

            private func verifyStandardsParsingAndCompletion() async throws {
                let session = makeSession()
                defer { session.invalidateAndCancel() }
                let stream = try await session.subscribe(try makeRequest(path: "standards"))
                var values: [String] = []
                for try await response in stream {
                    values.append(response.data.updates)
                }
                guard values == ["first"] else {
                    throw VerificationError.failed("Standards-compliant event was not decoded")
                }
            }

            private func verifyMissingCompletionFails() async throws {
                let session = makeSession()
                defer { session.invalidateAndCancel() }
                do {
                    let stream = try await session.subscribe(try makeRequest(path: "missing-complete"))
                    for try await _ in stream {}
                    throw VerificationError.failed("Missing complete event succeeded")
                } catch URLSession.SubscriptionError.missingCompleteEvent {}
            }

            private func verifyEventSizeIsBounded() async throws {
                let session = makeSession()
                defer { session.invalidateAndCancel() }
                do {
                    let stream = try await session.subscribe(
                        try makeRequest(path: "oversized"),
                        maximumEventByteCount: 8
                    )
                    for try await _ in stream {}
                    throw VerificationError.failed("Oversized event succeeded")
                } catch URLSession.SubscriptionError.eventTooLarge(let maximumByteCount) {
                    guard maximumByteCount == 8 else {
                        throw VerificationError.failed("Event limit error contained the wrong limit")
                    }
                }
            }

            private func verifyResultBufferIsBounded() async throws {
                let session = makeSession()
                defer { session.invalidateAndCancel() }
                let droppedResult = DispatchSemaphore(value: 0)
                let request = try GraphQLRequest(
                    subscription: OverflowProbeSubscription(),
                    endpoint: URL(string: "https://subscriptions.test/overflow")!
                )
                let stream = try await session.subscribe(
                    request,
                    decoder: { data in
                        let text = String(decoding: data, as: UTF8.self)
                        let signal =
                            text.contains("second") ? DroppedResultSignal(semaphore: droppedResult) : nil
                        return .success(
                            GraphQLResponse<OverflowProbeData>.Success(
                                data: OverflowProbeData(droppedResultSignal: signal),
                                fieldErrors: nil,
                                extensions: nil
                            )
                        )
                    },
                    maximumBufferedResultCount: 1
                )
                guard await waitForSignal(droppedResult) else {
                    throw VerificationError.failed("Timed out waiting for result buffer overflow")
                }
                do {
                    for try await _ in stream {}
                    throw VerificationError.failed("Result buffer overflow succeeded")
                } catch URLSession.SubscriptionError.resultBufferOverflow(let maximumBufferedResultCount) {
                    guard maximumBufferedResultCount == 1 else {
                        throw VerificationError.failed("Buffer overflow error contained the wrong limit")
                    }
                }
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
        """#.write(
            to: generatedDirectory.appending(path: "SubscriptionHarness.swift", directoryHint: .notDirectory),
            atomically: true,
            encoding: .utf8
        )

        var swiftSourcePaths: [String] = []
        if let enumerator = FileManager.default.enumerator(
            at: generatedDirectory,
            includingPropertiesForKeys: nil
        ) {
            while let sourceURL = enumerator.nextObject() as? URL {
                guard sourceURL.pathExtension == "swift" else { continue }
                swiftSourcePaths.append(sourceURL.path(percentEncoded: false))
            }
        }
        let executableURL = generatedDirectory.appending(
            path: "SubscriptionHarness",
            directoryHint: .notDirectory
        )
        let compilation = try run(
            executableURL: URL(fileURLWithPath: "/usr/bin/xcrun"),
            arguments: [
                "swiftc",
                "-swift-version", "6",
                "-o", executableURL.path(percentEncoded: false),
            ] + swiftSourcePaths
        )
        try #require(compilation.status == 0, Comment(rawValue: compilation.output))
        let verification = try run(executableURL: executableURL, arguments: [])
        #expect(verification.status == 0, Comment(rawValue: verification.output))
    }

    private func run(
        executableURL: URL,
        arguments: [String]
    ) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        let output = Pipe()
        process.standardError = output
        process.standardOutput = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (
            status: process.terminationStatus,
            output: String(decoding: data, as: UTF8.self)
        )
    }

}
