import Foundation
import GraphQLCodegen
import Testing

struct ConfigurationTests {
    @Test
    func rejectsNegativeIndentation() {
        #expect(throws: (any Error).self) {
            try Configuration.configuration(
                input: .input(
                    schemaSource: .SDLSchemaFile(URL(fileURLWithPath: "/tmp/schema.graphqls")),
                    documentDirectories: []
                ),
                output: .output(
                    indentation: .spaces(-1),
                    schema: .schema(directory: URL(fileURLWithPath: "/tmp/schema")),
                    api: .api(directory: URL(fileURLWithPath: "/tmp/api"))
                )
            )
        }
    }
}
