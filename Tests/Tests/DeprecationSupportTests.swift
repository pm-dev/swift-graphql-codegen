import Foundation
import Testing
@testable import GraphQLCodegen

struct DeprecationSupportTests {
    struct DeprecatedUsage: Sendable {
        let document: String
        let expectedMessage: String
    }

    private let schema = """
    directive @format(
      old: String @deprecated(reason: "Use style.")
      style: String
    ) on FIELD

    enum SearchOrder {
      OLD @deprecated(reason: "Use NEW.")
      NEW
    }

    input SearchInput {
      old: String @deprecated(reason: "Use newValue.")
      newValue: String
    }

    type Query {
      oldField: String @deprecated(reason: "Use search.")
      search(
        input: SearchInput
        old: String @deprecated(reason: "Use new.")
        new: String
        order: SearchOrder
      ): String!
    }
    """

    @Test(arguments: [
        DeprecatedUsage(
            document: #"query Search { search(old: "value") }"#,
            expectedMessage: #"The argument "Query.search(old:)" is deprecated. Use new."#
        ),
        DeprecatedUsage(
            document: #"query Search { search @format(old: "legacy") }"#,
            expectedMessage: #"The argument "@format(old:)" is deprecated. Use style."#
        ),
    ])
    func reportsDeprecatedArgumentsWhenIncluded(_ usage: DeprecatedUsage) async throws {
        let fixture = try makeFixture(document: usage.document)
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let diagnostics = try await diagnostics(in: fixture, policy: .include)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.issues.map(\.message) == [usage.expectedMessage])
    }

    @Test(arguments: [
        DeprecatedUsage(
            document: "query Search { oldField }",
            expectedMessage: "The field Query.oldField is deprecated. Use search."
        ),
        DeprecatedUsage(
            document: #"query Search { search(old: "value") }"#,
            expectedMessage: #"The argument "Query.search(old:)" is deprecated. Use new."#
        ),
        DeprecatedUsage(
            document: #"query Search { search @format(old: "legacy") }"#,
            expectedMessage: #"The argument "@format(old:)" is deprecated. Use style."#
        ),
        DeprecatedUsage(
            document: #"query Search { search(input: { old: "value" }) }"#,
            expectedMessage: "The input field SearchInput.old is deprecated. Use newValue."
        ),
        DeprecatedUsage(
            document: "query Search { search(order: OLD) }",
            expectedMessage: #"The enum value "SearchOrder.OLD" is deprecated. Use NEW."#
        ),
    ])
    func rejectsEveryDeprecatedUsageWhenExcluded(_ usage: DeprecatedUsage) async throws {
        let fixture = try makeFixture(document: usage.document)
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        do {
            _ = try await diagnostics(in: fixture, policy: .exclude)
            Issue.record("Expected deprecated usage to be rejected")
        } catch {
            let excludedUsageError = try #require(
                error as? DeprecationUsageValidator.ExcludedUsageError
            )
            #expect(excludedUsageError.description.contains(usage.expectedMessage))
        }
    }

    @Test
    func reportsDeprecatedUsageAtItsOriginalFragmentLocation() async throws {
        let fragment = """
        fragment SearchFragment on Query {
          search(old: "value")
        }
        """
        let fixture = try makeFixture(
            document: "query Search { ...SearchFragment }",
            additionalDocuments: ["SearchFragment.graphql": fragment]
        )
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let diagnostics = try await diagnostics(in: fixture, policy: .include)
        let diagnostic = try #require(diagnostics.first)
        let location = try #require(diagnostic.issues.first?.locations.first)

        #expect(diagnostic.documentURL.lastPathComponent == "SearchFragment.graphql")
        #expect(location.line == 2)
        #expect(location.column == 10)
    }

    @Test(arguments: [false, true])
    func rejectsDeprecatedUsageFromJSONSchema(isGraphQLResponse: Bool) async throws {
        let fixture = try makeFixture(document: #"query Search { search(old: "value") }"#)
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let graphQLJS = try GraphQLJS()
        let introspection = try graphQLJS.convertSDLSchema(
            schema,
            introspectionQuery: IntrospectionQuery().query
        )
        let schemaJSONURL = fixture.directory.appending(path: "schema.json", directoryHint: .notDirectory)
        let schemaJSON = isGraphQLResponse ? "{\"data\":\(introspection.text)}" : introspection.text
        try schemaJSON.write(to: schemaJSONURL, atomically: true, encoding: .utf8)
        let configuration = makeConfiguration(
            schemaSource: .JSONSchemaFile(schemaJSONURL),
            deprecationPolicy: .exclude,
            fixture: fixture
        )

        await #expect(throws: DeprecationUsageValidator.ExcludedUsageError.self) {
            try await Codegen(configuration).run()
        }
    }

    @Test
    func excludesDeprecatedInputObjectPropertiesAndEnumCases() async throws {
        let fixture = try makeFixture(
            document: """
            query Search($input: SearchInput, $order: SearchOrder) {
              search(input: $input, order: $order)
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let configuration = makeConfiguration(
            schemaSource: .SDLSchemaFile(fixture.schemaURL),
            deprecationPolicy: .exclude,
            fixture: fixture
        )

        try await Codegen(configuration).run()

        let generatedSchema = try String(
            contentsOf: fixture.schemaTypesDirectory.appending(path: "Schema.swift", directoryHint: .notDirectory),
            encoding: .utf8
        )
        #expect(!generatedSchema.contains("old"))
        #expect(generatedSchema.contains("newValue"))
        #expect(!generatedSchema.contains("OLD"))
        #expect(generatedSchema.contains("NEW"))
    }

    @Test
    func backsDeprecatedResponsePropertiesUsedByCustomDecoders() async throws {
        let fixture = try makeFixture(
            document: """
            query Search {
              oldField
              ...SearchFragment
            }

            fragment SearchFragment on Query {
              search
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        try await Codegen(
            makeConfiguration(
                schemaSource: .SDLSchemaFile(fixture.schemaURL),
                deprecationPolicy: .include,
                fixture: fixture
            )
        ).run()

        let generated = try String(
            contentsOf: fixture.operationsDirectory.appending(
                path: "Search.graphql.swift",
                directoryHint: .notDirectory
            ),
            encoding: .utf8
        )
        #expect(generated.contains("private let __oldField: String?"))
        #expect(generated.contains("var oldField: String? { __oldField }"))
        #expect(generated.contains("case __oldField = \"oldField\""))
        #expect(generated.contains("__oldField = try container.decode(String?.self, forKey: .oldField)"))
    }

    @Test
    func avoidsDeprecatedBackingStorageCollisionsWithResponseKeys() async throws {
        let fixture = try makeFixture(
            document: """
            query Search {
              foo: oldField
              __foo: search
              ...SearchFragment
            }

            fragment SearchFragment on Query {
              search
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        try await Codegen(
            makeConfiguration(
                schemaSource: .SDLSchemaFile(fixture.schemaURL),
                deprecationPolicy: .include,
                fixture: fixture
            )
        ).run()

        let generated = try String(
            contentsOf: fixture.operationsDirectory.appending(
                path: "Search.graphql.swift",
                directoryHint: .notDirectory
            ),
            encoding: .utf8
        )
        #expect(generated.contains("private let ___foo: String?"))
        #expect(generated.contains("var foo: String? { ___foo }"))
        #expect(generated.contains("let __foo: String"))
        #expect(generated.contains("case ___foo = \"foo\""))
        #expect(generated.contains("case __foo"))
        #expect(generated.contains("___foo = try container.decode(String?.self, forKey: .foo)"))
    }

    private func diagnostics(
        in fixture: Fixture,
        policy: Configuration.Input.DeprecationPolicy
    ) async throws -> [DeprecationUsageValidator.Diagnostic] {
        let configuration = makeConfiguration(
            schemaSource: .SDLSchemaFile(fixture.schemaURL),
            deprecationPolicy: policy,
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
        return try DeprecationUsageValidator(
            documents: documents,
            graphQLJS: graphQLJS,
            policy: policy,
            schemaJSON: loadedSchema.schemaJSON
        ).validate()
    }

    private func makeConfiguration(
        schemaSource: Configuration.Input.SchemaSource,
        deprecationPolicy: Configuration.Input.DeprecationPolicy,
        fixture: Fixture
    ) -> Configuration {
        .configuration(
            input: .input(
                schemaSource: schemaSource,
                documentDirectories: [fixture.operationsDirectory],
                deprecationPolicy: deprecationPolicy
            ),
            output: .output(
                schema: .schema(directory: fixture.schemaTypesDirectory),
                documents: .documents(directory: .directory(fixture.operationsDirectory)),
                support: .support(directory: fixture.directory.appending(path: "Support", directoryHint: .isDirectory))
            )
        )
    }

    private func makeFixture(
        document: String,
        additionalDocuments: [String: String] = [:]
    ) throws -> Fixture {
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
        for (fileName, sourceText) in additionalDocuments {
            try sourceText.write(
                to: operationsDirectory.appending(path: fileName, directoryHint: .notDirectory),
                atomically: true,
                encoding: .utf8
            )
        }
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
