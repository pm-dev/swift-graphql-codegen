@testable import Fixtures
import Foundation
import GraphQLCodegen
import Testing

struct GraphQLOneOfGeneratorTests {
    private static let testsDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    private let definitionsDirectory = GraphQLOneOfGeneratorTests.testsDirectory
        .appending(path: "Fixtures/Definitions/OneOf", directoryHint: .isDirectory)
    private let expectedDirectory = GraphQLOneOfGeneratorTests.testsDirectory
        .appending(path: "Fixtures/Generated/OneOf", directoryHint: .isDirectory)

    @Test
    func generatesEnumsWithGraphQLObjectEncodingAndIndirectRecursion() async throws {
        let generatedDirectory = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: generatedDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: generatedDirectory)
        }
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
                    schemaSource: .file(.SDL(schemaURL)),
                    documentDirectories: [operationsDirectory]
                ),
                output: .output(
                    schema: .schema(
                        directory: schemaTypesDirectory,
                        inputObjects: .inputObjects(conformances: ["Codable", "Hashable", "Sendable"])
                    ),
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
            contentsOf: expectedDirectory.appending(path: "SearchInput.graphqls.swift"),
            encoding: .utf8
        ).trimmingCharacters(in: .newlines)
        #expect(generated == expected)

        let generatedFilter = try String(
            contentsOf: schemaTypesDirectory.appending(path: "InputObjects/SearchFilterInput.graphqls.swift"),
            encoding: .utf8
        ).trimmingCharacters(in: .newlines)
        let expectedFilter = try String(
            contentsOf: expectedDirectory.appending(path: "SearchFilterInput.graphqls.swift"),
            encoding: .utf8
        ).trimmingCharacters(in: .newlines)
        #expect(generatedFilter == expectedFilter)
    }

    @Test
    func encodesOnlyTheSelectedField() throws {
        let data = try JSONEncoder().encode(SearchInput.name("Leia"))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])

        #expect(object == ["name": "Leia"])
    }

    @Test
    func encodesFieldNamedCodingKeys() throws {
        let data = try JSONEncoder().encode(SearchInput.CodingKeys("Leia"))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])

        #expect(object == ["CodingKeys": "Leia"])
    }

    @Test
    func decodesGraphQLObjectEncoding() throws {
        let input = SearchInput.id(7)
        let data = try JSONEncoder().encode(input)

        #expect(try JSONDecoder().decode(SearchInput.self, from: data) == input)
    }

    @Test
    func rejectsMultipleDecodedFields() {
        let data = Data(#"{"id":7,"name":"Leia"}"#.utf8)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(SearchInput.self, from: data)
        }
    }
}
