import Foundation
import GraphQLCodegen

@main
enum GraphQLCodegenCommand {
    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count == 2 else { throw CommandError.invalidArguments }

        let configurationURL = URL(fileURLWithPath: arguments[0]).standardizedFileURL
        let outputDirectory = URL(fileURLWithPath: arguments[1]).standardizedFileURL
        let fileConfiguration = try JSONDecoder().decode(
            FileConfiguration.self,
            from: Data(contentsOf: configurationURL)
        )
        try await Codegen(
            fileConfiguration.configuration(
                relativeTo: configurationURL.deletingLastPathComponent(),
                outputDirectory: outputDirectory
            )
        ).run()
    }
}

extension GraphQLCodegenCommand {
    private struct FileConfiguration: Decodable {
        struct Schema: Decodable {
            let path: String
            let importedModules: [String]?
            let scalarMappings: [String: String]?
        }

        struct Output: Decodable {
            struct Schema: Decodable {
                let accessLevel: AccessLevel?
            }

            struct Documents: Decodable {
                let accessLevel: AccessLevel?
            }

            struct API: Decodable {
                let accessLevel: AccessLevel?
                let subscriptionSupport: Bool?
            }

            let schema: Schema?
            let documents: Documents?
            let api: API?
        }

        enum AccessLevel: String, Decodable {
            case `internal`
            case `public`

            var configurationAccessLevel: Configuration.Output.AccessLevel {
                switch self {
                case .internal: .internal
                case .public: .public
                }
            }
        }

        enum DeprecationPolicy: String, Decodable {
            case exclude
            case include

            var configurationPolicy: Configuration.Input.DeprecationPolicy {
                switch self {
                case .exclude: .exclude
                case .include: .include
                }
            }
        }

        let schema: Schema
        let documentDirectories: [String]
        let deprecationPolicy: DeprecationPolicy?
        let output: Output?
        let validation: Bool?

        func configuration(
            relativeTo directory: URL,
            outputDirectory: URL
        ) -> Configuration {
            .buildPluginConfiguration(
                input: .input(
                    schemaFile: schemaFile(relativeTo: directory),
                    documentDirectories: documentDirectories.map { path in
                        directory.appending(path: path, directoryHint: .isDirectory)
                            .standardizedFileURL
                    },
                    deprecationPolicy: deprecationPolicy?.configurationPolicy ?? .include
                ),
                validation: validation ?? true,
                output: .generatedFiles(
                    directory: outputDirectory,
                    schema: .schema(
                        importedModules: schema.importedModules ?? [],
                        scalarMappings: schema.scalarMappings ?? [:],
                        accessLevel: output?.schema?.accessLevel?.configurationAccessLevel ?? .internal
                    ),
                    documents: .documents(
                        accessLevel: output?.documents?.accessLevel?.configurationAccessLevel ?? .internal
                    ),
                    api: .api(
                        accessLevel: output?.api?.accessLevel?.configurationAccessLevel ?? .internal,
                        HTTPSupport: .httpSupport(
                            subscriptionSupport: output?.api?.subscriptionSupport ?? false
                        )
                    )
                )
            )
        }

        private func schemaFile(
            relativeTo directory: URL
        ) -> Configuration.Input.SchemaSource.SchemaFile {
            let schemaURL = directory.appending(path: schema.path, directoryHint: .notDirectory)
                .standardizedFileURL
            return schemaURL.pathExtension.lowercased() == "json" ?
                .introspectionJSON(schemaURL) : .SDL(schemaURL)
        }
    }

    private enum CommandError: Error, CustomStringConvertible {
        case invalidArguments

        var description: String {
            switch self {
            case .invalidArguments:
                "Usage: graphql-codegen <configuration-file> <output-directory>"
            }
        }
    }
}
