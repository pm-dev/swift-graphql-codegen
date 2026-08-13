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
                support: .support(directory: URL(fileURLWithPath: "/tmp/support"))
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

    @Test(arguments: ["Decodable", "Sendable"])
    func rejectsResponseDataMissingRequiredHTTPConformance(_ missingConformance: String) async {
        let configuration = configuration(
            responseDataConformances: ["Decodable", "Sendable"].filter { $0 != missingConformance }
        )

        do {
            try await Codegen(configuration).run()
            Issue.record("Expected HTTP response data to require \(missingConformance)")
        } catch {
            #expect(String(describing: error) == """
            HTTP support requires output.documents.operations.responseData.conformances to include Decodable and Sendable.
            """)
        }
    }

    @Test(arguments: ["Encodable", "Sendable"])
    func rejectsVariablesMissingRequiredHTTPConformance(_ missingConformance: String) async {
        let configuration = configuration(
            variableConformances: ["Encodable", "Sendable"].filter { $0 != missingConformance }
        )

        do {
            try await Codegen(configuration).run()
            Issue.record("Expected HTTP variables to require \(missingConformance)")
        } catch {
            #expect(String(describing: error) == """
            HTTP support requires output.documents.operations.variables.conformances to include Encodable and Sendable.
            """)
        }
    }

    @Test(arguments: [false, true])
    func acceptsEquivalentRequiredHTTPConformances(_ qualified: Bool) async {
        let configuration = configuration(
            responseDataConformances: qualified
                ? ["Swift.Decodable", "@unchecked Swift.Sendable"]
                : ["Codable", "Sendable"],
            variableConformances: qualified
                ? ["Swift.Encodable", "@unchecked Sendable"]
                : ["Swift.Codable", "Swift.Sendable"]
        )

        await expectSchemaValidationError(for: configuration)
    }

    @Test
    func allowsMissingOperationConformancesWithoutHTTPSupport() async {
        let configuration = configuration(
            responseDataConformances: [],
            variableConformances: [],
            httpSupport: nil
        )

        await expectSchemaValidationError(for: configuration)
    }

    private func configuration(
        responseDataConformances: [String] = ["Decodable", "Sendable"],
        variableConformances: [String] = ["Encodable", "Sendable"],
        httpSupport: Configuration.Output.Support.HTTPSupport? = .httpSupport()
    ) -> Configuration {
        Configuration.configuration(
            input: .input(
                schemaSource: .SDLSchemaFile(URL(string: "https://example.com/schema.graphqls")!),
                documentDirectories: []
            ),
            output: .output(
                schema: .schema(directory: URL(fileURLWithPath: "/tmp/schema")),
                documents: .documents(
                    operations: .operations(
                        variables: .variables(conformances: variableConformances),
                        responseData: .responseData(conformances: responseDataConformances)
                    )
                ),
                support: .support(
                    directory: URL(fileURLWithPath: "/tmp/support"),
                    HTTPSupport: httpSupport
                )
            )
        )
    }

    private func expectSchemaValidationError(for configuration: Configuration) async {
        do {
            try await Codegen(configuration).run()
            Issue.record("Expected codegen to reject the nonlocal schema URL")
        } catch {
            #expect(String(describing: error).contains("must be a local file"))
        }
    }
}
