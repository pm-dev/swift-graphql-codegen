import Foundation
@testable import GraphQLCodegen
import Testing

struct GraphQLBoundaryTests {
    @Test
    func canonicalizationPreservesLiteralWhitespaceAndRemovesComments() throws {
        let source = #"""
        query Search {
          search(text: "two  spaces")
          # This comment must not consume the next field.
          block(text: """two
            lines""")
        }
        """#

        let canonical = GraphQLJS.canonicalizeDocument(source)

        #expect(canonical.contains(#""two  spaces""#))
        #expect(canonical.contains("two\n"))
        #expect(!canonical.contains("This comment"))
        #expect(try DocumentASTParser(sourceText: canonical).parse().definitions.count == 1)
    }

    @Test
    func swiftMultilineLiteralSelectsANonconflictingDelimiter() {
        let value = "value \"\"\"# and \\#(interpolation)"
        let literal = SwiftStringLiteral.multiline(value)

        #expect(literal.hasPrefix("##\"\"\"\n"))
        #expect(literal.hasSuffix("\n\"\"\"##"))
        #expect(literal.contains(value))
        #expect(SwiftStringLiteral.blockComment("value */ next") == "/* value * / next */")
    }

    @Test
    func scannerReturnsStablePathOrder() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in ["z.graphql", "a.graphql", "m.graphql.swift"] {
            try Data().write(to: directory.appending(path: name))
        }

        let scan = try DocumentScanner(directories: [directory]).scan()

        #expect(scan.documentFileURLs.map(\.lastPathComponent) == ["a.graphql", "z.graphql"])
        #expect(scan.generatedFileURLs.map(\.lastPathComponent) == ["m.graphql.swift"])
    }

    @Test
    func discardedOutputDoesNotLeakIntoTheNextTransaction() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let discardedURL = directory.appending(path: "discarded.txt")
        let committedURL = directory.appending(path: "committed.txt")

        let discarded = FileOutput()
        try await discarded.write(Data("discarded".utf8), to: discardedURL)
        await discarded.discard()

        let committed = FileOutput()
        try await committed.write(Data("committed".utf8), to: committedURL)
        try await committed.execute()

        #expect(!FileManager.default.fileExists(atPath: discardedURL.path))
        #expect(try String(contentsOf: committedURL, encoding: .utf8) == "committed")
    }

    @Test
    func failedOutputCommitRestoresReplacedFiles() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let existingURL = directory.appending(path: "existing.txt")
        let blockingParent = directory.appending(path: "not-a-directory")
        try Data("original".utf8).write(to: existingURL)
        try Data("blocking".utf8).write(to: blockingParent)

        let output = FileOutput()
        try await output.write(Data("replacement".utf8), to: existingURL)
        try await output.write(Data("invalid".utf8), to: blockingParent.appending(path: "child.txt"))

        await #expect(throws: (any Error).self) {
            try await output.execute()
        }
        #expect(try String(contentsOf: existingURL, encoding: .utf8) == "original")
    }

    @Test
    func introspectionRequestIncludesCustomHeaders() throws {
        let runner = IntrospectionRunner(
            endpoint: URL(string: "https://example.com/graphql")!,
            headers: ["Authorization": "Bearer token"],
            includeDeprecatedFields: true,
            includeDeprecatedEnumValues: true,
            urlSession: .shared
        )

        let request = try runner.request()

        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        #expect(request.value(forHTTPHeaderField: "accept") == "application/graphql-response+json")
    }

    @Test
    func introspectionRejectsHTTPErrorResponses() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UnauthorizedURLProtocol.self]
        let runner = IntrospectionRunner(
            endpoint: URL(string: "https://example.com/graphql")!,
            headers: [:],
            includeDeprecatedFields: true,
            includeDeprecatedEnumValues: true,
            urlSession: URLSession(configuration: configuration)
        )

        do {
            _ = try await runner.run()
            Issue.record("Expected the introspection request to reject HTTP 401")
        } catch {
            #expect(String(describing: error).contains("HTTP 401"))
        }
    }
}

private class UnauthorizedURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
