import Foundation
import GraphQLCodegen
import Testing

struct GraphQLDefaultValuesGeneratorTests {
    private static let testsDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Inside 'Tests'
        .deletingLastPathComponent() // Inside root 'Tests'
    private let definitionsDirectory = GraphQLDefaultValuesGeneratorTests.testsDirectory
        .appending(path: "Fixtures/Definitions/Defaults", directoryHint: .isDirectory)
    private let expectedDirectory = GraphQLDefaultValuesGeneratorTests.testsDirectory
        .appending(path: "Fixtures/Generated/Defaults", directoryHint: .isDirectory)

    @Test
    func testGeneratesDefaultValuesAPI() async throws {
        let generatedDirectory = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: generatedDirectory, withIntermediateDirectories: true)
        defer {
            // Best-effort test cleanup; retaining a temporary directory does not affect test behavior.
            try? FileManager.default.removeItem(at: generatedDirectory)
        }
        try FileManager.default.copyItem(
            at: definitionsDirectory.appending(path: "schema.sdl", directoryHint: .notDirectory),
            to: generatedDirectory.appending(path: "schema.sdl", directoryHint: .notDirectory)
        )
        let fixtureOperationsDirectory = definitionsDirectory.appending(
            path: "Operations",
            directoryHint: .isDirectory
        )
        let operationsDirectory = generatedDirectory.appending(path: "Operations", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: operationsDirectory, withIntermediateDirectories: true)
        for documentURL in try files(in: fixtureOperationsDirectory, withSuffix: ".graphql") {
            try FileManager.default.copyItem(
                at: documentURL,
                to: operationsDirectory.appending(
                    path: documentURL.lastPathComponent,
                    directoryHint: .notDirectory
                )
            )
        }
        try await Codegen(
            .configuration(
                input: .input(
                    schemaSource: .file(.SDL(
                        generatedDirectory.appending(path: "schema.sdl", directoryHint: .notDirectory)
                    )),
                    documentDirectories: [operationsDirectory]
                ),
                output: .output(
                    schema: .schema(
                        directory: generatedDirectory.appending(
                            path: "SchemaTypes",
                            directoryHint: .isDirectory
                        )
                    ),
                    documents: .documents(
                        directory: .definition,
                        operations: .operations(persistedOperations: nil)
                    ),
                    api: .api(
                        directory: generatedDirectory.appending(path: "API", directoryHint: .isDirectory),
                        HTTPSupport: nil
                    )
                )
            )
        ).run()

        #expect(
            !FileManager.default.fileExists(
                atPath: generatedDirectory.appending(
                    path: "API/HTTPSupport",
                    directoryHint: .isDirectory
                ).path(percentEncoded: false)
            )
        )
        try verifyFiles(
            expected: files(in: expectedDirectory, withSuffix: ".graphqls.swift"),
            generated: files(
                in: generatedDirectory.appending(path: "SchemaTypes", directoryHint: .isDirectory),
                withSuffix: ".graphqls.swift"
            )
        )
        try verifyFiles(
            expected: files(
                in: expectedDirectory.appending(path: "Operations", directoryHint: .isDirectory),
                withSuffix: ".graphql.swift"
            ),
            generated: files(in: operationsDirectory, withSuffix: ".graphql.swift")
        )
    }

    private func files(in directory: URL, withSuffix suffix: String) throws -> [URL] {
        try FileManager.default.subpathsOfDirectory(atPath: directory.path(percentEncoded: false))
            .filter { $0.hasSuffix(suffix) }
            .map { directory.appending(path: $0, directoryHint: .notDirectory) }
            .sorted { $0.path < $1.path }
    }

    private func verifyFiles(
        expected: [URL],
        generated: [URL]
    ) throws {
        let expectedFileNames = Set(expected.map(\.lastPathComponent))
        let generatedFileNames = Set(generated.map(\.lastPathComponent))
        #expect(expected.count == expectedFileNames.count)
        #expect(generated.count == generatedFileNames.count)
        #expect(generatedFileNames == expectedFileNames)

        for expectedURL in expected {
            let generatedURL = try #require(
                generated.first { $0.lastPathComponent == expectedURL.lastPathComponent }
            )
            let expectedSource = try String(contentsOf: expectedURL, encoding: .utf8)
                .trimmingCharacters(in: .newlines)
            let generatedSource = try String(contentsOf: generatedURL, encoding: .utf8)
                .trimmingCharacters(in: .newlines)
            #expect(generatedSource == expectedSource)
        }
    }
}
