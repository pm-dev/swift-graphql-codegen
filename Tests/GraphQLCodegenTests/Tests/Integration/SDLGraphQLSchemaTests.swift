import Foundation
import GraphQLCodegen
import Testing

struct SDLGraphQLSchemaTests {
    @Test
    func loadsGraphQLSchemaWithoutScanningItAsOperation() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let definitions = root.appending(path: "Definitions", directoryHint: .isDirectory)
        let output = root.appending(path: "Output", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: definitions, withIntermediateDirectories: true)

        let schema = definitions.appending(path: "schema.graphql", directoryHint: .notDirectory)
        try Data("type Query { hero: String! }".utf8).write(to: schema)
        try Data("query Hero { hero }".utf8).write(
            to: definitions.appending(path: "Hero.graphql", directoryHint: .notDirectory)
        )

        try await Codegen(
            .configuration(
                input: .input(
                    schemaSource: .SDLSchemaFile(schema),
                    documentDirectories: [definitions]
                ),
                output: .output(
                    schema: .schema(
                        directory: output.appending(path: "Schema", directoryHint: .isDirectory)
                    ),
                    documents: .documents(
                        directory: .directory(
                            output.appending(path: "Operations", directoryHint: .isDirectory)
                        )
                    ),
                    api: .api(
                        directory: output.appending(path: "API", directoryHint: .isDirectory)
                    )
                )
            )
        ).run()

        #expect(
            FileManager.default.fileExists(
                atPath: output
                    .appending(path: "Operations/Hero.graphql.swift", directoryHint: .notDirectory)
                    .path(percentEncoded: false)
            )
        )
    }
}
