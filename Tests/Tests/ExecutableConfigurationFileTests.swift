import Foundation
@testable import graphql_codegen
import GraphQLCodegen
import Testing

struct ExecutableConfigurationFileTests {
    @Test
    func rejectsMissingRequiredExecutableConfiguration() throws {
        let decoder = JSONDecoder()

        #expect(throws: DecodingError.self) {
            try decoder.decode(
                ExecutableConfigurationFile.self,
                from: Data(#"{"input":{"schemaSource":"schema.graphqls","documentDirectories":[]}}"#.utf8)
            )
        }
        #expect(throws: DecodingError.self) {
            try decoder.decode(
                ExecutableConfigurationFile.Output.self,
                from: Data(#"{"support":{"directory":"Support"}}"#.utf8)
            )
        }
        #expect(throws: DecodingError.self) {
            try decoder.decode(
                ExecutableConfigurationFile.Output.self,
                from: Data(#"{"schema":{"directory":"Schema"}}"#.utf8)
            )
        }
        do {
            _ = try configuration(
                from:
                """
                {
                  "input": {
                    "schemaSource": "schema.graphqls",
                    "documentDirectories": []
                  },
                  "output": {
                    "schema": {},
                    "support": { "directory": "Support" }
                  }
                }
                """
            )
            Issue.record("Expected executable configuration to require a schema output directory")
        } catch {
            #expect(String(describing: error) == "Missing required output directory: output.schema.directory")
        }

        do {
            _ = try configuration(
                from:
                """
                {
                  "input": {
                    "schemaSource": "schema.graphqls",
                    "documentDirectories": []
                  },
                  "output": {
                    "schema": { "directory": "Schema" },
                    "support": {}
                  }
                }
                """
            )
            Issue.record("Expected executable configuration to require a support output directory")
        } catch {
            #expect(String(describing: error) == "Missing required output directory: output.support.directory")
        }
    }

    @Test
    func decodesScalarMappingsWithModuleDefaults() throws {
        let configuration = try configuration(
            from:
            """
            {
              "input": {
                "schemaSource": "schema.graphqls",
                "documentDirectories": []
              },
              "output": {
                "schema": {
                  "directory": "Schema",
                  "scalars": {
                    "scalarMapping": {
                      "UUID": {
                        "typeName": "UUID",
                        "module": { "name": "Foundation" }
                      }
                    }
                  }
                },
                "support": { "directory": "Support" }
              }
            }
            """
        )
        let scalar = try #require(configuration.output.schema.scalars.scalarMapping["UUID"])
        #expect(scalar.typeName == "UUID")
        #expect(scalar.module?.name == "Foundation")
        #expect(scalar.module?.prefix == false)
    }

    @Test
    func decodesExplicitHTTPSupportAndPersistedOperationChoices() throws {
        let disabledHTTP = try configuration(httpSupport: #"{"enabled":false}"#)
        #expect(disabledHTTP.output.support.HTTPSupport == nil)

        let disabledPersistence = try configuration(
            httpSupport: #"{"persistedOperations":{"strategy":"disabled"}}"#
        )
        #expect(disabledPersistence.output.support.HTTPSupport != nil)
        #expect(disabledPersistence.output.support.HTTPSupport?.persistedOperations == nil)

        let registeredByDefault = try configuration(
            httpSupport: #"{"persistedOperations":{"strategy":"registered"}}"#
        )
        guard case .registered(let defaultAllowUnregisteredOperations)? =
            registeredByDefault.output.support.HTTPSupport?.persistedOperations
        else {
            Issue.record("Expected registered persisted operations with the factory default")
            return
        }
        #expect(!defaultAllowUnregisteredOperations)

        let registered = try configuration(
            httpSupport: #"{"persistedOperations":{"strategy":"registered","allowUnregisteredOperations":true}}"#
        )
        guard case .registered(let allowUnregisteredOperations)? =
            registered.output.support.HTTPSupport?.persistedOperations
        else {
            Issue.record("Expected registered persisted operations")
            return
        }
        #expect(allowUnregisteredOperations)
    }

    @Test
    func decodesIntrospectionEndpointsWithoutBuildPluginRestrictions() throws {
        let configuration = try configuration(
            from:
            """
            {
              "input": {
                "schemaSource": "https://example.com/graphql",
                "schemaHeaders": { "Authorization": "Bearer token" },
                "documentDirectories": []
              },
              "output": {
                "schema": { "directory": "Schema" },
                "support": { "directory": "Support" }
              }
            }
            """
        )

        guard case .introspectionEndpoint(let url, let headers) = configuration.input.schemaSource else {
            Issue.record("Expected an introspection endpoint")
            return
        }
        #expect(url.absoluteString == "https://example.com/graphql")
        #expect(headers["Authorization"] == "Bearer token")
    }

    @Test
    func decodesExecutableConfigurationOptions() throws {
        let configuration = try configuration(
            from:
            """
            {
              "input": {
                "schemaSource": "schema.graphqls",
                "documentDirectories": ["Documents"],
                "deprecationPolicy": "exclude"
              },
              "output": {
                "indentation": { "style": "tab" },
                "schema": {
                  "directory": "Schema",
                  "includeHeader": false,
                  "scalars": {
                    "scalarMapping": {
                      "UUID": {
                        "typeName": "UUID",
                        "module": { "name": "Foundation", "prefix": true }
                      }
                    }
                  },
                  "enums": {
                    "caseConversion": { "from": "macro", "to": "lowerCamel" }
                  },
                  "accessLevel": "public"
                },
                "documents": {
                  "includeHeader": false,
                  "accessLevel": "public"
                },
                "support": {
                  "directory": "Support",
                  "httpSupport": {
                    "persistedOperations": { "strategy": "disabled" }
                  }
                }
              }
            }
            """
        )

        #expect(configuration.input.deprecationPolicy == .exclude)
        #expect(configuration.output.schema.header == nil)
        #expect(configuration.output.schema.accessLevel == .public)
        #expect(configuration.output.schema.scalars.scalarMapping["UUID"]?.module?.prefix == true)
        #expect(configuration.output.schema.enums.caseConversion?.from == .macro)
        #expect(configuration.output.schema.enums.caseConversion?.to == .lowerCamel)
        #expect(configuration.output.documents.header == nil)
        #expect(configuration.output.documents.accessLevel == .public)
        #expect(configuration.output.support.HTTPSupport != nil)
        #expect(configuration.output.support.HTTPSupport?.persistedOperations == nil)
        guard case .tab = configuration.output.indentation else {
            Issue.record("Expected tab indentation to be decoded")
            return
        }
        guard case .definition = configuration.output.documents.directory else {
            Issue.record("Expected document output beside its definition")
            return
        }
    }

    @Test(arguments: [false, true])
    func appliesExecutableOutputDirectoryOverride(hasConfiguredDirectories: Bool) throws {
        let schema = hasConfiguredDirectories ? #"{"directory":"Schema"}"# : "{}"
        let documents = hasConfiguredDirectories ? #"{"directory":"Documents","accessLevel":"public"}"# : "null"
        let support = hasConfiguredDirectories ? #"{"directory":"Support"}"# : "{}"
        let outputDirectory = URL(fileURLWithPath: "/tmp/GraphQLProject/Generated")
        let configuration = try configuration(
            from:
            """
            {
              "input": {
                "schemaSource": "schema.graphqls",
                "documentDirectories": ["Documents"]
              },
              "output": {
                "schema": \(schema),
                "documents": \(documents),
                "support": \(support)
              }
            }
            """,
            outputDirectory: outputDirectory
        )

        #expect(configuration.output.schema.directory == outputDirectory)
        #expect(configuration.output.support.directory == outputDirectory)
        guard case .directory(let documentsDirectory) = configuration.output.documents.directory else {
            Issue.record("Expected generated documents to use the output directory override")
            return
        }
        #expect(documentsDirectory == outputDirectory)
        if hasConfiguredDirectories {
            #expect(configuration.output.documents.accessLevel == .public)
        }
    }

    @Test(
        arguments: [
            ("schemaSource", "/tmp/schema.graphqls"),
            ("schemaSource", "file:///tmp/schema.graphqls"),
            ("documentDirectories", "/tmp/Documents"),
            ("output.schema.directory", "/tmp/Schema"),
            ("output.documents.directory", "/tmp/Documents"),
            ("output.support.directory", "/tmp/Support"),
        ]
    )
    func rejectsAbsoluteFileURLs(parameter: String, value: String) throws {
        let schemaSource = parameter == "schemaSource" ? value : "schema.graphqls"
        let documentsDirectory = parameter == "documentDirectories" ? value : "Documents"
        let schemaOutput = parameter == "output.schema.directory" ? value : "Schema"
        let documentsOutput = parameter == "output.documents.directory" ? value : "Generated/Documents"
        let supportOutput = parameter == "output.support.directory" ? value : "Support"
        do {
            _ = try configuration(
                from:
                """
                {
                  "input": {
                    "schemaSource": "\(schemaSource)",
                    "documentDirectories": ["\(documentsDirectory)"]
                  },
                  "output": {
                    "schema": { "directory": "\(schemaOutput)" },
                    "documents": { "directory": "\(documentsOutput)" },
                    "support": { "directory": "\(supportOutput)" }
                  }
                }
                """
            )
            Issue.record("Expected \(parameter) to reject an absolute file URL")
        } catch {
            #expect(String(describing: error).contains("\(parameter) must be relative to the configuration file"))
        }
    }

    private func configuration(httpSupport json: String) throws -> Configuration {
        try configuration(
            from:
            """
            {
              "input": {
                "schemaSource": "schema.graphqls",
                "documentDirectories": []
              },
              "output": {
                "schema": { "directory": "Schema" },
                "support": {
                  "directory": "Support",
                  "httpSupport": \(json)
                }
              }
            }
            """
        )
    }

    private func configuration(
        from json: String,
        outputDirectory: URL? = nil
    ) throws -> Configuration {
        let configurationFile = try JSONDecoder().decode(
            ExecutableConfigurationFile.self,
            from: Data(json.utf8)
        )
        return try configurationFile.configuration(
            relativeTo: URL(fileURLWithPath: "/tmp/GraphQLProject"),
            outputDirectory: outputDirectory
        )
    }
}
