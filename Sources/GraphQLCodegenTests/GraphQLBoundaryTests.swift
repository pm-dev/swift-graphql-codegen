import Foundation
import GraphQLCodegen
import Testing

struct GraphQLBoundaryTests {
    @Test
    func generatedLiteralsPreserveGraphQLTextWhenRawEscapesArePresent() async throws {
        let fixture = try CodegenFixture.create()
        defer { fixture.remove() }
        let documentURL = try fixture.writeDocument(
            named: "Escaped",
            source: ##"""
            query Escaped {
              search(text: "two  spaces")
              # This comment must not consume the next field.
              block(text: """a\#nb""")
            }
            """##
        )
        let output = fixture.output(named: "escaped")

        try await Codegen(
            try fixture.configuration(
                documentDirectories: [documentURL.deletingLastPathComponent()],
                output: output
            )
        ).run()

        let generatedURL = output.documents.appending(path: "Escaped.graphql.swift")
        let generated = try String(contentsOf: generatedURL, encoding: .utf8)
        let document = try SwiftLiteralEvaluator(source: generated).value(of: "document")
        let minifiedDocument = try SwiftLiteralEvaluator(source: generated).value(of: "minifiedDocument")

        #expect(document.contains(##"a\#nb"##))
        #expect(!document.contains("a\nb"))
        #expect(minifiedDocument.contains(##"a\#nb"##))
        #expect(minifiedDocument.contains(#""two  spaces""#))
        #expect(!minifiedDocument.contains("This comment"))
    }

    @Test
    func generatedOutputIsDeterministicAcrossInputDirectoryOrder() async throws {
        let fixture = try CodegenFixture.create()
        defer { fixture.remove() }
        let firstDirectory = try fixture.writeDocument(
            named: "Alpha",
            source: "query Alpha { search(text: \"alpha\") }",
            directoryName: "first"
        ).deletingLastPathComponent()
        let secondDirectory = try fixture.writeDocument(
            named: "Beta",
            source: "query Beta { search(text: \"beta\") }",
            directoryName: "second"
        ).deletingLastPathComponent()
        let firstOutput = fixture.output(named: "first-output")
        let secondOutput = fixture.output(named: "second-output")
        let firstManifest = firstOutput.root.appending(path: "manifest.json")
        let secondManifest = secondOutput.root.appending(path: "manifest.json")

        try await Codegen(
            try fixture.configuration(
                documentDirectories: [secondDirectory, firstDirectory],
                output: firstOutput,
                persistedOperations: .registered(manifestJSONFileOutput: firstManifest)
            )
        ).run()
        try await Codegen(
            try fixture.configuration(
                documentDirectories: [firstDirectory, secondDirectory],
                output: secondOutput,
                persistedOperations: .registered(manifestJSONFileOutput: secondManifest)
            )
        ).run()

        #expect(try Data(contentsOf: firstManifest) == Data(contentsOf: secondManifest))
    }

    @Test
    func concurrentRunsKeepTheirOutputTransactionsIsolated() async throws {
        let firstFixture = try CodegenFixture.create()
        let secondFixture = try CodegenFixture.create()
        defer {
            firstFixture.remove()
            secondFixture.remove()
        }
        let firstDocument = try firstFixture.writeDocument(
            named: "First",
            source: "query First { search(text: \"first\") }"
        )
        let secondDocument = try secondFixture.writeDocument(
            named: "Second",
            source: "query Second { search(text: \"second\") }"
        )
        let firstOutput = firstFixture.output(named: "output")
        let secondOutput = secondFixture.output(named: "output")
        let firstConfiguration = try firstFixture.configuration(
            documentDirectories: [firstDocument.deletingLastPathComponent()],
            output: firstOutput
        )
        let secondConfiguration = try secondFixture.configuration(
            documentDirectories: [secondDocument.deletingLastPathComponent()],
            output: secondOutput
        )

        async let firstRun: Void = Codegen(firstConfiguration).run()
        async let secondRun: Void = Codegen(secondConfiguration).run()
        _ = try await (firstRun, secondRun)

        #expect(FileManager.default.fileExists(atPath: firstOutput.documents.appending(path: "First.graphql.swift").path))
        #expect(!FileManager.default.fileExists(atPath: firstOutput.documents.appending(path: "Second.graphql.swift").path))
        #expect(FileManager.default.fileExists(atPath: secondOutput.documents.appending(path: "Second.graphql.swift").path))
        #expect(!FileManager.default.fileExists(atPath: secondOutput.documents.appending(path: "First.graphql.swift").path))
    }

    @Test
    func failedCommitRestoresPreviouslyGeneratedFiles() async throws {
        let fixture = try CodegenFixture.create()
        defer { fixture.remove() }
        let documentURL = try fixture.writeDocument(
            named: "Rollback",
            source: "query Rollback { search(text: \"rollback\") }"
        )
        let validOutput = fixture.output(named: "rollback")
        try FileManager.default.createDirectory(at: validOutput.documents, withIntermediateDirectories: true)
        let generatedURL = validOutput.documents.appending(path: "Rollback.graphql.swift")
        try Data("original".utf8).write(to: generatedURL)
        let blockingAPIDirectory = validOutput.root.appending(path: "not-a-directory")
        try Data("blocking".utf8).write(to: blockingAPIDirectory)
        let output = CodegenFixture.OutputDirectories(
            root: validOutput.root,
            api: blockingAPIDirectory,
            documents: validOutput.documents,
            schema: validOutput.schema
        )

        await #expect(throws: (any Error).self) {
            try await Codegen(
                try fixture.configuration(
                    documentDirectories: [documentURL.deletingLastPathComponent()],
                    output: output
                )
            ).run()
        }
        #expect(try String(contentsOf: generatedURL, encoding: .utf8) == "original")
    }

    @Test
    func introspectionUsesEndpointHeadersAndRejectsHTTPFailures() async throws {
        let fixture = try CodegenFixture.create()
        defer { fixture.remove() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UnauthorizedURLProtocol.self]
        let endpoint = URL(string: "https://example.com/graphql")!

        do {
            try await Codegen(
                try fixture.configuration(
                    schemaSource: .introspectionEndpoint(
                        url: endpoint,
                        headers: ["Authorization": "Bearer token"]
                    ),
                    documentDirectories: [],
                    output: fixture.output(named: "introspection")
                ),
                urlSession: URLSession(configuration: configuration)
            ).run()
            Issue.record("Expected the introspection request to reject HTTP 401")
        } catch {
            #expect(String(describing: error).contains("HTTP 401"))
        }
    }
}

private struct CodegenFixture {
    struct OutputDirectories {
        let root: URL
        let api: URL
        let documents: URL
        let schema: URL
    }

    let root: URL
    let schemaURL: URL

    static func create() throws -> Self {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let schemaURL = root.appending(path: "schema.graphqls")
        try Data("""
        type Query {
          search(text: String!): String
          block(text: String!): String
        }
        """.utf8).write(to: schemaURL)
        return Self(root: root, schemaURL: schemaURL)
    }

    func output(named name: String) -> OutputDirectories {
        let outputRoot = root.appending(path: name, directoryHint: .isDirectory)
        return OutputDirectories(
            root: outputRoot,
            api: outputRoot.appending(path: "API", directoryHint: .isDirectory),
            documents: outputRoot.appending(path: "Operations", directoryHint: .isDirectory),
            schema: outputRoot.appending(path: "Schema", directoryHint: .isDirectory)
        )
    }

    func configuration(
        schemaSource: Configuration.Input.SchemaSource? = nil,
        documentDirectories: [URL],
        output: OutputDirectories,
        persistedOperations: Configuration.Output.Documents.Operations.PersistedOperations? = .automatic
    ) throws -> Configuration {
        try .configuration(
            input: .input(
                schemaSource: schemaSource ?? .SDLSchemaFile(schemaURL),
                documentDirectories: documentDirectories
            ),
            output: .output(
                schema: .schema(directory: output.schema),
                documents: .documents(
                    directory: .directory(output.documents),
                    operations: .operations(persistedOperations: persistedOperations)
                ),
                api: .api(directory: output.api)
            )
        )
    }

    func writeDocument(
        named name: String,
        source: String,
        directoryName: String = "Documents"
    ) throws -> URL {
        let directory = root.appending(path: directoryName, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(name).graphql")
        try Data(source.utf8).write(to: url)
        return url
    }

    func remove() {
        do {
            try FileManager.default.removeItem(at: root)
        } catch {
            Issue.record("Failed to remove test fixture at \(root.path): \(error)")
        }
    }
}

private struct SwiftLiteralEvaluator {
    struct EvaluationError: Error, CustomStringConvertible {
        let description: String
    }

    let source: String

    func value(of property: String) throws -> String {
        let expression = try literalExpression(of: property)
        let scriptURL = FileManager.default.temporaryDirectory
            .appending(path: "\(UUID().uuidString).swift")
        defer {
            do {
                try FileManager.default.removeItem(at: scriptURL)
            } catch {
                Issue.record("Failed to remove Swift evaluation script: \(error)")
            }
        }
        try Data("""
        let value = \(expression)
        print(value, terminator: "")
        """.utf8).write(to: scriptURL)

        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["swift", scriptURL.path]
        process.standardOutput = standardOutput
        process.standardError = standardError
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let error = String(
                data: standardError.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? "Unknown Swift compiler error"
            throw EvaluationError(description: error)
        }
        return String(
            data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )!
    }

    private func literalExpression(of property: String) throws -> Substring {
        let marker = "static let \(property) = "
        guard let markerRange = source.range(of: marker) else {
            throw EvaluationError(description: "Missing generated property \(property)")
        }
        let remainder = source[markerRange.upperBound...]
        guard let openingQuotes = remainder.range(of: "\"\"\"") else {
            throw EvaluationError(description: "Missing opening delimiter for \(property)")
        }
        let hashes = remainder[..<openingQuotes.lowerBound]
        let closingDelimiter = "\"\"\"" + hashes
        guard let closingRange = remainder.range(
            of: closingDelimiter,
            range: openingQuotes.upperBound..<remainder.endIndex
        ) else {
            throw EvaluationError(description: "Missing closing delimiter for \(property)")
        }
        return remainder[..<closingRange.upperBound]
    }
}

private final class UnauthorizedURLProtocol: URLProtocol, @unchecked Sendable {
    override static func canInit(with request: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let hasAuthorization = request.value(forHTTPHeaderField: "Authorization") == "Bearer token"
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: hasAuthorization ? 401 : 400,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
