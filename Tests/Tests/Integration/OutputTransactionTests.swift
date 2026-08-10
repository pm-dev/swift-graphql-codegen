import Foundation
import GraphQLCodegen
import Testing

struct OutputTransactionTests {
    @Test
    func replacesSeparateDocumentOutputDirectory() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let configuration = configuration(for: fixture)
        try await Codegen(configuration).run()

        let documentsDirectory = fixture.output.appending(
            path: "Operations",
            directoryHint: .isDirectory
        )
        let generatedDocument = documentsDirectory.appending(
            path: "Value.graphql.swift",
            directoryHint: .notDirectory
        )
        let unrelatedFile = documentsDirectory.appending(
            path: "README.md",
            directoryHint: .notDirectory
        )
        let unrelatedContents = "Keep this file.\n"
        try Data(unrelatedContents.utf8).write(to: unrelatedFile)

        #expect(FileManager.default.fileExists(atPath: generatedDocument.path(percentEncoded: false)))

        try FileManager.default.removeItem(
            at: fixture.operations.appending(path: "Value.graphql", directoryHint: .notDirectory)
        )
        try await Codegen(configuration).run()

        #expect(!FileManager.default.fileExists(atPath: generatedDocument.path(percentEncoded: false)))
        #expect(!FileManager.default.fileExists(atPath: unrelatedFile.path(percentEncoded: false)))
    }

    @Test
    func preservesCustomScalarSourcesIncludingBuiltInID() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let scalarsDirectory = fixture.output.appending(
            path: "Schema/Scalars",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: scalarsDirectory,
            withIntermediateDirectories: true
        )
        let customScalarURL = scalarsDirectory.appending(
            path: "Custom.graphqls.swift",
            directoryHint: .notDirectory
        )
        let customSource = "typealias Custom = UUID\n"
        try Data(customSource.utf8).write(to: customScalarURL)
        let idScalarURL = scalarsDirectory.appending(
            path: "ID.graphqls.swift",
            directoryHint: .notDirectory
        )
        let idSource = "struct ID: Codable, Sendable { let rawValue: String }\n"
        try Data(idSource.utf8).write(to: idScalarURL)

        try await Codegen(configuration(for: fixture)).run()

        #expect(try String(contentsOf: customScalarURL, encoding: .utf8) == customSource)
        #expect(try String(contentsOf: idScalarURL, encoding: .utf8) == idSource)
    }

    @Test
    func restoresNestedOutputAfterCommitFailure() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let generatedSchemaDirectory = fixture.output.appending(
            path: "Schema/Generated",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: generatedSchemaDirectory, withIntermediateDirectories: true)
        let sentinelURL = generatedSchemaDirectory.appending(path: "sentinel.txt", directoryHint: .notDirectory)
        let sentinel = "existing output\n"
        try Data(sentinel.utf8).write(to: sentinelURL)

        let blockingFile = fixture.root.appending(path: "0-blocker", directoryHint: .notDirectory)
        try Data().write(to: blockingFile)
        let configuration = configuration(
            for: fixture,
            schema: .schema(
                directory: fixture.output.appending(path: "Schema", directoryHint: .isDirectory),
                scalars: .scalars(directoryName: "Generated"),
                enums: .enums(directoryName: "Generated/Enums"),
                inputObjects: .inputObjects(directoryName: "Generated/InputObjects")
            ),
            supportDirectory: blockingFile.appending(path: "Support", directoryHint: .isDirectory)
        )

        var failed = false
        do {
            try await Codegen(configuration).run()
        } catch {
            failed = true
        }

        #expect(failed)
        #expect(try String(contentsOf: sentinelURL, encoding: .utf8) == sentinel)
        #expect(
            !FileManager.default.fileExists(
                atPath: generatedSchemaDirectory
                    .appending(path: "Custom.graphqls.swift", directoryHint: .notDirectory)
                    .path(percentEncoded: false)
            )
        )
    }

    private func configuration(
        for fixture: Fixture,
        schema: Configuration.Output.Schema? = nil,
        supportDirectory: URL? = nil
    ) -> Configuration {
        .configuration(
            input: .input(
                schemaSource: .SDLSchemaFile(fixture.schema),
                documentDirectories: [fixture.operations]
            ),
            output: .output(
                schema: schema ?? .schema(
                    directory: fixture.output.appending(path: "Schema", directoryHint: .isDirectory)
                ),
                documents: .documents(
                    directory: .directory(
                        fixture.output.appending(path: "Operations", directoryHint: .isDirectory)
                    )
                ),
                support: .support(
                    directory: supportDirectory ?? fixture.output.appending(path: "Support", directoryHint: .isDirectory)
                )
            )
        )
    }

    private func makeFixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        let definitions = root.appending(path: "Definitions", directoryHint: .isDirectory)
        let operations = definitions.appending(path: "Operations", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: operations, withIntermediateDirectories: true)
        let schema = definitions.appending(path: "schema.sdl", directoryHint: .notDirectory)
        try Data(
            """
            scalar Custom
            enum Choice { A }
            input Filter { value: Custom, choice: Choice }
            type Query { id: ID!, value(filter: Filter): Custom! }
            """.utf8
        ).write(to: schema)
        try Data(
            """
            query Value($filter: Filter) {
              id
              value(filter: $filter)
            }
            """.utf8
        ).write(to: operations.appending(path: "Value.graphql", directoryHint: .notDirectory))
        return Fixture(
            root: root,
            schema: schema,
            operations: operations,
            output: root.appending(path: "Output", directoryHint: .isDirectory)
        )
    }
}

private struct Fixture {
    let root: URL
    let schema: URL
    let operations: URL
    let output: URL
}
