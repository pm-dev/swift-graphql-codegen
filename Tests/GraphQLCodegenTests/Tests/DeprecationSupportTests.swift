import Foundation
@testable import GraphQLCodegen
import Testing

struct DeprecationSupportTests {
    private let schema = """
    directive @format(
      old: String @deprecated(reason: "Use style.")
      style: String
    ) on FIELD

    type Query {
      search(
        input: SearchInput
        old: String @deprecated(reason: "Use new.")
        new: String
      ): String!
    }

    input SearchInput {
      old: String @deprecated(reason: "Use newValue.")
      newValue: String
    }
    """

    @Test
    func reportsDeprecatedFieldArgumentWhenIncluded() async throws {
        let fixture = try makeFixture(
            document: #"query Search { search(old: "value") }"#
        )
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let configuration = makeConfiguration(
            schemaSource: .SDLSchemaFile(fixture.schemaURL, deprecationPolicy: .include),
            fixture: fixture
        )
        let graphQLJS = try GraphQLJS()
        let loadedSchema = try await SchemaLoader(
            configuration: configuration,
            graphQLJS: graphQLJS,
            urlSession: .shared
        ).load()
        let documents = try DocumentsLoader(
            configuration: configuration,
            graphQLJS: graphQLJS
        ).load()

        let diagnostics = try DeprecationUsageValidator(
            documents: documents,
            graphQLJS: graphQLJS,
            policy: .include,
            schemaJSON: loadedSchema.schemaJSON
        ).validate()

        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostics.count == 1)
        #expect(diagnostic.operationName == "Search")
        #expect(diagnostic.issues.map(\.message) == [#"The argument "Query.search(old:)" is deprecated. Use new."#])
    }

    @Test
    func reportsDeprecatedDirectiveArgumentWhenIncluded() async throws {
        let fixture = try makeFixture(
            document: #"query Search { search @format(old: "legacy") }"#
        )
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let configuration = makeConfiguration(
            schemaSource: .SDLSchemaFile(fixture.schemaURL, deprecationPolicy: .include),
            fixture: fixture
        )
        let graphQLJS = try GraphQLJS()
        let loadedSchema = try await SchemaLoader(
            configuration: configuration,
            graphQLJS: graphQLJS,
            urlSession: .shared
        ).load()
        let documents = try DocumentsLoader(
            configuration: configuration,
            graphQLJS: graphQLJS
        ).load()

        let diagnostics = try DeprecationUsageValidator(
            documents: documents,
            graphQLJS: graphQLJS,
            policy: .include,
            schemaJSON: loadedSchema.schemaJSON
        ).validate()

        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic.issues.map(\.message) == [#"The argument "@format(old:)" is deprecated. Use style."#])
    }

    @Test
    func reportsDeprecatedUsageAtFragmentSourceLocation() async throws {
        let fixture = try makeFixture(
            document: """
            query Search {
              ...SearchFragment
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let fragmentURL = fixture.operationsDirectory.appending(
            path: "SearchFragment.graphql",
            directoryHint: .notDirectory
        )
        try #"""
        fragment SearchFragment on Query {
          search(old: "value")
        }
        """#.write(to: fragmentURL, atomically: true, encoding: .utf8)
        let configuration = makeConfiguration(
            schemaSource: .SDLSchemaFile(fixture.schemaURL, deprecationPolicy: .include),
            fixture: fixture
        )
        let graphQLJS = try GraphQLJS()
        let loadedSchema = try await SchemaLoader(
            configuration: configuration,
            graphQLJS: graphQLJS,
            urlSession: .shared
        ).load()
        let documents = try DocumentsLoader(
            configuration: configuration,
            graphQLJS: graphQLJS
        ).load()

        let diagnostic = try #require(
            DeprecationUsageValidator(
                documents: documents,
                graphQLJS: graphQLJS,
                policy: .include,
                schemaJSON: loadedSchema.schemaJSON
            ).validate().first
        )
        let location = try #require(diagnostic.issues.first?.locations.first)

        #expect(location.documentURL.resolvingSymlinksInPath() == fragmentURL.resolvingSymlinksInPath())
        #expect(location.line == 2)
        #expect(location.column == 10)
    }

    @Test
    func rejectsDeprecatedUsageFromJSONSchemaWhenValidationIsDisabled() async throws {
        let fixture = try makeFixture(
            document: #"query Search { search(old: "value") }"#
        )
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let graphQLJS = try GraphQLJS()
        let introspection = try graphQLJS.convertSDLSchema(
            schema,
            introspectionQuery: IntrospectionQuery().query
        )
        let schemaJSONURL = fixture.directory.appending(path: "schema.json", directoryHint: .notDirectory)
        try introspection.text.write(to: schemaJSONURL, atomically: true, encoding: .utf8)
        let configuration = makeConfiguration(
            schemaSource: .JSONSchemaFile(schemaJSONURL, deprecationPolicy: .exclude),
            fixture: fixture
        )

        do {
            try await Codegen(configuration).run()
            Issue.record("Expected code generation to reject deprecated argument usage")
        } catch {
            let description = String(describing: error)
            #expect(description.contains("Deprecated schema member usage is excluded"))
            #expect(description.contains(#"The argument "Query.search(old:)" is deprecated. Use new."#))
        }
    }

    @Test
    func excludesDeprecatedInputObjectProperties() async throws {
        let fixture = try makeFixture(
            document: "query Search($input: SearchInput) { search(input: $input) }"
        )
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let configuration = makeConfiguration(
            schemaSource: .SDLSchemaFile(fixture.schemaURL, deprecationPolicy: .exclude),
            fixture: fixture
        )

        try await Codegen(configuration).run()

        let generated = try String(
            contentsOf: fixture.schemaTypesDirectory.appending(
                path: "InputObjects/SearchInput.graphqls.swift",
                directoryHint: .notDirectory
            ),
            encoding: .utf8
        )
        #expect(!generated.contains("old"))
        #expect(generated.contains("newValue"))
    }

    private func makeConfiguration(
        schemaSource: Configuration.Input.SchemaSource,
        fixture: Fixture
    ) -> Configuration {
        .configuration(
            input: .input(
                schemaSource: schemaSource,
                documentDirectories: [fixture.operationsDirectory]
            ),
            validation: false,
            output: .output(
                schema: .schema(directory: fixture.schemaTypesDirectory),
                documents: .documents(directory: .directory(fixture.operationsDirectory)),
                api: .api(directory: fixture.directory.appending(path: "API", directoryHint: .isDirectory))
            )
        )
    }

    private func makeFixture(document: String) throws -> Fixture {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        let operationsDirectory = directory.appending(path: "Operations", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: operationsDirectory, withIntermediateDirectories: true)
        let schemaURL = directory.appending(path: "schema.sdl", directoryHint: .notDirectory)
        try schema.write(to: schemaURL, atomically: true, encoding: .utf8)
        try document.write(
            to: operationsDirectory.appending(path: "Search.graphql", directoryHint: .notDirectory),
            atomically: true,
            encoding: .utf8
        )
        return Fixture(
            directory: directory,
            operationsDirectory: operationsDirectory,
            schemaTypesDirectory: directory.appending(path: "SchemaTypes", directoryHint: .isDirectory),
            schemaURL: schemaURL
        )
    }
}

private struct Fixture {
    let directory: URL
    let operationsDirectory: URL
    let schemaTypesDirectory: URL
    let schemaURL: URL
}
