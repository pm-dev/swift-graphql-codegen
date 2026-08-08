import Foundation
import GraphQLCodegen
import Testing

struct GraphQLOneOfGeneratorTests {
    private static let testsDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    private let fixtureDirectory = GraphQLOneOfGeneratorTests.testsDirectory
        .appending(path: "Fixtures/OneOf", directoryHint: .isDirectory)

    @Test
    func generatesEnumWithGraphQLObjectEncoding() async throws {
        let generatedDirectory = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: generatedDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: generatedDirectory)
        }
        let definitionsDirectory = fixtureDirectory.appending(path: "Definitions", directoryHint: .isDirectory)
        let operationsDirectory = generatedDirectory.appending(path: "Operations", directoryHint: .isDirectory)
        try FileManager.default.copyItem(
            at: definitionsDirectory.appending(path: "Operations", directoryHint: .isDirectory),
            to: operationsDirectory
        )
        let schemaURL = definitionsDirectory.appending(path: "schema.sdl", directoryHint: .notDirectory)
        let schemaTypesDirectory = generatedDirectory.appending(path: "SchemaTypes", directoryHint: .isDirectory)

        try await Codegen(
            .configuration(
                input: .input(
                    schemaSource: .SDLSchemaFile(schemaURL),
                    documentDirectories: [operationsDirectory]
                ),
                output: .output(
                    schema: .schema(directory: schemaTypesDirectory),
                    documents: .documents(directory: .directory(operationsDirectory)),
                    api: .api(directory: generatedDirectory.appending(path: "API", directoryHint: .isDirectory))
                )
            )
        ).run()

        let generated = try String(
            contentsOf: schemaTypesDirectory.appending(path: "InputObjects/SearchInput.graphqls.swift"),
            encoding: .utf8
        ).trimmingCharacters(in: .newlines)
        let expected = try String(
            contentsOf: fixtureDirectory.appending(path: "Generated/SearchInput.graphqls.swift"),
            encoding: .utf8
        ).trimmingCharacters(in: .newlines)
        #expect(generated == expected)
    }

    @Test
    func encodesOnlyTheSelectedField() throws {
        let data = try JSONEncoder().encode(SearchInput.name("Leia"))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])

        #expect(object == ["name": "Leia"])
    }
}
