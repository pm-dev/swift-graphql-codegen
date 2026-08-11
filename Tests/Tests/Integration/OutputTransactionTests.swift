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
    func regeneratesSchemaUsingConfiguredScalarMappings() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let schemaDirectory = fixture.output.appending(
            path: "Schema",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: schemaDirectory,
            withIntermediateDirectories: true
        )
        let schemaURL = schemaDirectory.appending(
            path: "Schema.swift",
            directoryHint: .notDirectory
        )
        try Data("typealias Custom = UUID\n".utf8).write(to: schemaURL)
        let unrelatedURL = schemaDirectory.appending(
            path: "README.md",
            directoryHint: .notDirectory
        )
        let unrelatedContents = "Keep this file.\n"
        try Data(unrelatedContents.utf8).write(to: unrelatedURL)

        var configuration = configuration(
            for: fixture,
            schema: .schema(
                directory: schemaDirectory,
                header: "// generated schema",
                importedModules: ["Swift"],
                scalars: .scalars(
                    scalarMapping: ["Custom": .scalar(typeName: "UUID", module: .module(name: "Foundation"))]
                )
            )
        )
        try await Codegen(configuration).run()

        let generatedSource = try String(contentsOf: schemaURL, encoding: .utf8)
        #expect(generatedSource.hasPrefix("// generated schema\n"))
        #expect(generatedSource.contains("import Foundation\n"))
        #expect(generatedSource.contains("import Swift\n"))
        #expect(generatedSource.contains("typealias Custom = UUID"))
        #expect(generatedSource.contains("typealias ID = String"))
        #expect(generatedSource.contains("enum Choice"))
        #expect(generatedSource.contains("struct Filter"))
        #expect(try String(contentsOf: unrelatedURL, encoding: .utf8) == unrelatedContents)
        let generatedFiles = try FileManager.default.contentsOfDirectory(
            atPath: schemaDirectory.path(percentEncoded: false)
        )
        #expect(generatedFiles.sorted() == ["README.md", "Schema.swift"])

        configuration.output.schema.scalars.scalarMapping = [
            "Custom": .scalar(typeName: "URL", module: .module(name: "Foundation", prefix: true)),
            "ID": .scalar(typeName: "Int"),
        ]
        try await Codegen(configuration).run()

        let updatedSource = try String(contentsOf: schemaURL, encoding: .utf8)
        #expect(updatedSource.contains("import Foundation\n"))
        #expect(updatedSource.contains("import Swift\n"))
        #expect(updatedSource.contains("typealias Custom = Foundation.URL"))
        #expect(updatedSource.contains("typealias ID = Int"))
        #expect(try String(contentsOf: unrelatedURL, encoding: .utf8) == unrelatedContents)
    }

    @Test
    func restoresSchemaAfterCommitFailure() async throws {
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
        let schemaURL = generatedSchemaDirectory.appending(path: "Schema.swift", directoryHint: .notDirectory)
        let existingSchema = "typealias Custom = UUID\n"
        try Data(existingSchema.utf8).write(to: schemaURL)

        let blockingFile = fixture.root.appending(path: "0-blocker", directoryHint: .notDirectory)
        try Data().write(to: blockingFile)
        let configuration = configuration(
            for: fixture,
            schema: .schema(directory: generatedSchemaDirectory),
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
        #expect(try String(contentsOf: schemaURL, encoding: .utf8) == existingSchema)
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
