import Foundation
import GraphQLCodegen
import PluginFixtures
import Testing

struct ConfigurationTests {
    @Test
    func buildToolPluginGeneratesCompilableSources() {
        #expect(String(describing: PluginFixture().operationType) == "ValueQuery")
    }

    @Test
    func generatedFilesExposeBuildCommandOutputs() {
        let output: Configuration.Output.GeneratedFiles = .generatedFiles(
            directory: URL(fileURLWithPath: "/tmp/generated")
        )

        #expect(output.outputFiles.map(\.lastPathComponent) == [
            "GraphQLAPI.generated.swift",
            "GraphQLDocuments.generated.swift",
            "GraphQLSchema.generated.swift",
        ])
    }

    @Test
    func buildPluginConfigurationMapsIntrospectionJSONFiles() async {
        let configuration = buildPluginConfiguration(schemaFile: .introspectionJSON(
            URL(fileURLWithPath: "/tmp/schema.graphqls")
        ))

        await expectValidationError(configuration, containing: "introspectionJSON")
    }

    @Test
    func buildPluginConfigurationMapsSDLFiles() async {
        let configuration = buildPluginConfiguration(schemaFile: .SDL(
            URL(fileURLWithPath: "/tmp/schema.json")
        ))

        await expectValidationError(configuration, containing: "SDL")
    }

    @Test
    func buildPluginConfigurationRejectsRemoteSchemaFiles() async throws {
        let remoteSchema = try #require(URL(string: "https://example.com/schema.graphqls"))
        let configuration = buildPluginConfiguration(schemaFile: .SDL(remoteSchema))

        await expectValidationError(configuration, containing: "must be a local file")
    }

    @Test
    func validatesLatestConfigurationAtStartOfRun() async {
        var configuration = Configuration.configuration(
            input: .input(
                schemaSource: .file(.SDL(URL(fileURLWithPath: "/tmp/schema.graphqls"))),
                documentDirectories: []
            ),
            output: .output(
                indentation: .spaces(4),
                schema: .schema(directory: URL(fileURLWithPath: "/tmp/schema")),
                api: .api(directory: URL(fileURLWithPath: "/tmp/api"))
            )
        )
        configuration.output.indentation = .spaces(-1)

        do {
            try await Codegen(configuration).run()
            Issue.record("Expected codegen to reject the mutated configuration")
        } catch {
            #expect(String(describing: error) == "The indentation space count must not be negative.")
        }
    }

    @Test
    func generatedFilesRejectAdditionalPersistedOperationManifest() async {
        var configuration = Configuration.configuration(
            input: .input(
                schemaSource: .file(.SDL(URL(fileURLWithPath: "/tmp/schema.graphqls"))),
                documentDirectories: []
            ),
            output: .generatedFiles(directory: URL(fileURLWithPath: "/tmp/generated"))
        )
        configuration.output.api.HTTPSupport?.persistedOperations = .registered(
            manifestJSONFileOutput: URL(fileURLWithPath: "/tmp/manifest.json")
        )

        do {
            try await Codegen(configuration).run()
            Issue.record("Expected generated-files output to reject an additional manifest")
        } catch {
            #expect(String(describing: error).contains("only supports its three declared Swift files"))
        }
    }

    private func buildPluginConfiguration(
        schemaFile: Configuration.Input.SchemaSource.SchemaFile
    ) -> Configuration {
        .buildPluginConfiguration(
            input: .input(
                schemaFile: schemaFile,
                documentDirectories: []
            ),
            output: .generatedFiles(
                directory: URL(fileURLWithPath: "/tmp/generated")
            )
        )
    }

    private func expectValidationError(
        _ configuration: Configuration,
        containing expectedText: String
    ) async {
        do {
            try await Codegen(configuration).run()
            Issue.record("Expected build plugin configuration to be rejected")
        } catch {
            #expect(String(describing: error).contains(expectedText))
        }
    }
}
