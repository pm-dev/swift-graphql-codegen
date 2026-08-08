import Foundation
import GraphQLCodegen
import Testing

struct ConfigurationTests {
    @Test
    func validatesLatestConfigurationAtStartOfRun() async {
        var configuration = Configuration.configuration(
            input: .input(
                schemaSource: .SDLSchemaFile(URL(fileURLWithPath: "/tmp/schema.graphqls")),
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
}
