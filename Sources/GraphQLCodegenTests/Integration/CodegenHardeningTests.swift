import Dispatch
import Foundation
import GraphQLCodegen
import Testing

struct CodegenHardeningTests {
    private struct ProbeTimeout: Error, CustomStringConvertible {
        let description: String
    }

    private enum Persistence: CaseIterable {
        case automatic
        case none
        case registered

        func configuration(manifestURL: URL) -> Configuration.Output.Documents.Operations.PersistedOperations? {
            switch self {
            case .automatic: .automatic
            case .none: nil
            case .registered: .registered(manifestJSONFileOutput: manifestURL)
            }
        }
    }

    private struct Workspace {
        let root: URL

        var documents: URL {
            root.appending(path: "Documents", directoryHint: .isDirectory)
        }

        var schema: URL {
            root.appending(path: "schema.sdl", directoryHint: .notDirectory)
        }

        func output(_ name: String) -> URL {
            root.appending(path: "Generated/\(name)", directoryHint: .isDirectory)
        }

        func write(_ contents: String, to relativePath: String) throws {
            let url = root.appending(path: relativePath, directoryHint: .notDirectory)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    @Test
    func generatedHTTPConfigurationsCompile() async throws {
        let workspace = try makeWorkspace()
        defer { remove(workspace) }
        try workspace.write(
            """
            type Query {
              search(filter: Filter): SearchResult!
            }

            type Mutation {
              update: String!
            }

            type Subscription {
              updates: String!
            }

            input Filter {
              nested: Filter
              children: [Filter!]
            }

            type SearchResult {
              value: String!
            }
            """,
            to: "schema.sdl"
        )
        try workspace.write(
            """
            # 😀 exercises graphql-js UTF-16 source locations.
            query Search($filter: Filter) {
              search(filter: $filter) {
                ...SearchResultFields
              }
            }

            fragment SearchResultFields on SearchResult {
              value
            }

            mutation Update {
              update
            }

            subscription Updates {
              updates
            }
            """,
            to: "Documents/Feature/Operations.graphql"
        )

        for enableGETQueries in [false, true] {
            for persistence in Persistence.allCases {
                let name = "\(enableGETQueries ? "GET" : "POST")-\(persistence)"
                let output = workspace.output(name)
                try await Codegen(
                    try configuration(
                        workspace: workspace,
                        output: output,
                        enableGETQueries: enableGETQueries,
                        persistence: persistence
                    )
                ).run()
                let operationOutput = output.appending(
                    path: "Documents/Feature/Operations.graphql.swift",
                    directoryHint: .notDirectory
                )
                #expect(FileManager.default.fileExists(atPath: operationOutput.path(percentEncoded: false)))
                try typecheckSwiftSources(in: output)
                if !enableGETQueries, persistence == .automatic {
                    try verifyAutomaticPersistedOperationHashes(in: output)
                }
                if !enableGETQueries, persistence == .none {
                    try verifySubscriptionErrorsPropagate(in: output)
                }
            }
        }
    }

    @Test
    func missingFragmentWithoutValidationThrows() async throws {
        let workspace = try makeWorkspace()
        defer { remove(workspace) }
        try workspace.write("type Query { value: String! }", to: "schema.sdl")
        try workspace.write("query Missing { ...Unknown }", to: "Documents/Missing.graphql")

        await expectFailure {
            try await Codegen(
                .configuration(
                    input: .input(
                        schemaSource: .SDLSchemaFile(workspace.schema),
                        documentDirectories: [workspace.documents]
                    ),
                    validation: false,
                    output: .output(
                        schema: .schema(directory: workspace.output("Schema")),
                        api: .api(directory: workspace.output("API"))
                    )
                )
            ).run()
        }
    }

    @Test
    func collidingDocumentOutputsThrow() async throws {
        let workspace = try makeWorkspace()
        defer { remove(workspace) }
        let firstDocuments = workspace.root.appending(path: "First", directoryHint: .isDirectory)
        let secondDocuments = workspace.root.appending(path: "Second", directoryHint: .isDirectory)
        try workspace.write("type Query { value: String! }", to: "schema.sdl")
        try workspace.write("query First { value }", to: "First/Operation.graphql")
        try workspace.write("query Second { value }", to: "Second/Operation.graphql")

        await expectFailure {
            try await Codegen(
                .configuration(
                    input: .input(
                        schemaSource: .SDLSchemaFile(workspace.schema),
                        documentDirectories: [firstDocuments, secondDocuments]
                    ),
                    output: .output(
                        schema: .schema(directory: workspace.output("Schema")),
                        documents: .documents(
                            directory: .directory(workspace.output("Documents"))
                        ),
                        api: .api(directory: workspace.output("API"))
                    )
                )
            ).run()
        }
    }

    @Test
    func failedOutputCommitRestoresExistingGeneratedFiles() async throws {
        let workspace = try makeWorkspace()
        defer { remove(workspace) }
        let existingOutput = "// existing generated output\n"
        let blockedAPIRoot = workspace.root.appending(path: "Blocked", directoryHint: .notDirectory)
        try workspace.write("type Query { value: String! }", to: "schema.sdl")
        try workspace.write("query Operation { value }", to: "Documents/Operation.graphql")
        try workspace.write(existingOutput, to: "Documents/Operation.graphql.swift")
        try workspace.write("not a directory", to: "Blocked")

        await expectFailure {
            try await Codegen(
                .configuration(
                    input: .input(
                        schemaSource: .SDLSchemaFile(workspace.schema),
                        documentDirectories: [workspace.documents]
                    ),
                    output: .output(
                        schema: .schema(directory: workspace.output("Schema")),
                        api: .api(directory: blockedAPIRoot.appending(path: "API"))
                    )
                )
            ).run()
        }

        let restoredOutput = try String(
            contentsOf: workspace.documents.appending(path: "Operation.graphql.swift"),
            encoding: .utf8
        )
        #expect(restoredOutput == existingOutput)
    }

    private func configuration(
        workspace: Workspace,
        output: URL,
        enableGETQueries: Bool,
        persistence: Persistence
    ) throws -> Configuration {
        try .configuration(
            input: .input(
                schemaSource: .SDLSchemaFile(workspace.schema),
                documentDirectories: [workspace.documents]
            ),
            output: .output(
                schema: .schema(directory: output.appending(path: "Schema")),
                documents: .documents(
                    directory: .directory(output.appending(path: "Documents")),
                    operations: .operations(
                        persistedOperations: persistence.configuration(
                            manifestURL: output.appending(path: "manifest.json")
                        )
                    )
                ),
                api: .api(
                    directory: output.appending(path: "API"),
                    HTTPSupport: .httpSupport(
                        enableGETQueries: enableGETQueries,
                        subscriptionSupport: true
                    )
                )
            )
        )
    }

    private func expectFailure(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            Issue.record("Expected code generation to fail")
        } catch {
            // Failure is the behavior under test.
        }
    }

    private func makeWorkspace() throws -> Workspace {
        let workspace = Workspace(
            root: FileManager.default.temporaryDirectory
                .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        )
        try FileManager.default.createDirectory(at: workspace.root, withIntermediateDirectories: true)
        return workspace
    }

    private func remove(_ workspace: Workspace) {
        do {
            try FileManager.default.removeItem(at: workspace.root)
        } catch {
            Issue.record("Failed to remove test workspace at \(workspace.root): \(error)")
        }
    }

    private func typecheckSwiftSources(in directory: URL) throws {
        let sources = try swiftSources(in: directory)
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["swiftc", "-swift-version", "6", "-warnings-as-errors", "-typecheck"] +
            sources.map { $0.path(percentEncoded: false) }
        process.standardError = output
        process.standardOutput = output
        try process.run()
        process.waitUntilExit()
        let compilerOutput = try #require(
            String(
                data: try output.fileHandleForReading.readToEnd() ?? Data(),
                encoding: .utf8
            )
        )
        #expect(process.terminationStatus == 0, "Generated source failed to compile:\n\(compilerOutput)")
    }

    private func verifySubscriptionErrorsPropagate(in directory: URL) throws {
        try compileAndRunProbe(
            named: "SubscriptionErrorProbe",
            source: """
        import Foundation

        private struct ExpectedError: Error {}
        private struct InvalidEndpoint: Error {}
        private struct UnexpectedCompletion: Error {}

        private final class EventProtocol: URLProtocol {
            override class func canInit(with request: URLRequest) -> Bool { true }
            override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

            override func startLoading() {
                guard let url = request.url,
                      let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["content-type": "text/event-stream"]
                ) else {
                    client?.urlProtocol(self, didFailWithError: InvalidEndpoint())
                    return
                }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: Data("data: {}\\n\\n".utf8))
                client?.urlProtocolDidFinishLoading(self)
            }

            override func stopLoading() {}
        }

        @main
        private struct SubscriptionErrorProbe {
            static func main() async throws {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.protocolClasses = [EventProtocol.self]
                let session = URLSession(configuration: configuration)
                guard let endpoint = URL(string: "https://example.com/graphql") else {
                    throw InvalidEndpoint()
                }
                let request = try GraphQLRequest(
                    subscription: UpdatesSubscription(),
                    endpoint: endpoint
                )
                let stream = try await session.subscribe(request) { _ in throw ExpectedError() }
                do {
                    for try await _ in stream {}
                    throw UnexpectedCompletion()
                } catch is ExpectedError {
                    return
                }
            }
        }
        """,
            in: directory,
            timeoutMessage: "Subscription stream did not propagate its decoder error"
        )
    }

    private func verifyAutomaticPersistedOperationHashes(in directory: URL) throws {
        try compileAndRunProbe(
            named: "AutomaticHashProbe",
            source: """
        import CryptoKit
        import Foundation

        private struct HashMismatch: Error {}

        @main
        private struct AutomaticHashProbe {
            static func main() throws {
                guard SearchQuery.documentHash == hash(SearchQuery.document),
                      SearchQuery.minifiedDocumentHash == hash(SearchQuery.minifiedDocument) else {
                    let diagnostics =
                        "document: \\(SearchQuery.document.debugDescription)\\n" +
                        "generated document hash: \\(SearchQuery.documentHash)\\n" +
                        "runtime document hash: \\(hash(SearchQuery.document))\\n"
                    FileHandle.standardError.write(Data(diagnostics.utf8))
                    throw HashMismatch()
                }

                let operation = SearchQuery()
                try verifyEncodedHash(
                    operation: operation,
                    minifyDocument: false,
                    expected: SearchQuery.documentHash
                )
                try verifyEncodedHash(
                    operation: operation,
                    minifyDocument: true,
                    expected: SearchQuery.minifiedDocumentHash
                )
            }

            private static func verifyEncodedHash(
                operation: SearchQuery,
                minifyDocument: Bool,
                expected: String
            ) throws {
                let data = try JSONBodyEncoder().encode(
                    operation: operation,
                    automaticPersistedOperationPhase: .initialRequestWithHash,
                    minifyDocument: minifyDocument
                )
                guard let body = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let extensions = body["extensions"] as? [String: Any],
                      let persistedQuery = extensions["persistedQuery"] as? [String: Any],
                      let encodedHash = persistedQuery["sha256Hash"] as? String,
                      encodedHash == expected else {
                    throw HashMismatch()
                }
            }

            private static func hash(_ source: String) -> String {
                SHA256.hash(data: Data(source.utf8))
                    .map { String(format: "%02x", $0) }
                    .joined()
            }
        }
        """,
            in: directory,
            timeoutMessage: "Automatic persisted operation hash probe timed out"
        )
    }

    private func compileAndRunProbe(
        named name: String,
        source: String,
        in directory: URL,
        timeoutMessage: String
    ) throws {
        let harness = directory.appending(path: "\(name).swift", directoryHint: .notDirectory)
        try source.write(to: harness, atomically: true, encoding: .utf8)

        let executable = directory.appending(path: name, directoryHint: .notDirectory)
        let compiler = Process()
        let compilerOutput = Pipe()
        compiler.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        compiler.arguments = [
            "swiftc",
            "-swift-version", "6",
            "-warnings-as-errors",
            "-o", executable.path(percentEncoded: false),
        ] + (try swiftSources(in: directory)).map { $0.path(percentEncoded: false) }
        compiler.standardError = compilerOutput
        compiler.standardOutput = compilerOutput
        try compiler.run()
        compiler.waitUntilExit()
        let compilation = try #require(
            String(
                data: try compilerOutput.fileHandleForReading.readToEnd() ?? Data(),
                encoding: .utf8
            )
        )
        #expect(compiler.terminationStatus == 0, "Generated probe failed to compile:\n\(compilation)")
        guard compiler.terminationStatus == 0 else { return }

        let probe = Process()
        let exited = DispatchSemaphore(value: 0)
        probe.executableURL = executable
        probe.terminationHandler = { _ in exited.signal() }
        try probe.run()
        if exited.wait(timeout: .now() + 5) == .timedOut {
            probe.terminate()
            Issue.record(ProbeTimeout(description: timeoutMessage))
            return
        }
        #expect(probe.terminationStatus == 0)
    }

    private func swiftSources(in directory: URL) throws -> [URL] {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys)
        ) else {
            Issue.record("Could not enumerate generated sources at \(directory)")
            return []
        }
        return try enumerator.compactMap { element -> URL? in
            guard let url = element as? URL,
                  url.pathExtension == "swift",
                  try url.resourceValues(forKeys: resourceKeys).isRegularFile == true else {
                return nil
            }
            return url
        }
        .sorted { $0.path < $1.path }
    }
}
