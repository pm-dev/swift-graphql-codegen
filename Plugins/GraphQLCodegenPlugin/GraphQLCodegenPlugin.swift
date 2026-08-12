import Foundation
import PackagePlugin

@main
struct GraphQLCodegenPlugin: BuildToolPlugin {
    func createBuildCommands(
        context: PluginContext,
        target: any Target
    ) async throws -> [Command] {
        let configurationURL = try target.configurationURL()
        let configuration = try ExecutableConfigurationFile.at(configurationURL)
        try configuration.validateForBuildPlugin()
        let schemaURL = try configuration.resolveSchemaURL(relativeTo: target.directoryURL)
        let documentDirectories = try configuration.resolveDocumentDirectories(relativeTo: target.directoryURL)
        let documents = try DocumentScanner(directories: documentDirectories).scan(
            excluding: schemaURL,
            requiringUniqueFilenames: true
        )
        return [
            .buildCommand(
                displayName: "Generate GraphQL sources for \(target.name)",
                executable: try context.tool(named: "graphql-codegen").url,
                arguments: [
                    "--file-configuration",
                    configurationURL.path,
                    "--output-directory",
                    context.pluginWorkDirectoryURL.path,
                ],
                inputFiles: [configurationURL, schemaURL] + documents.map(\.url),
                outputFiles: [
                    context.outputSchemaURL,
                    context.outputSupportURL,
                ] + documents.map(context.outputDocumentURL(for:))
                    .sorted { $0.path < $1.path }
            ),
        ]
    }
}

extension Target {
    fileprivate func configurationURL() throws -> URL {
        let configurationURL = directoryURL.appending(
            path: "graphql-codegen.json",
            directoryHint: .notDirectory
        )
        guard FileManager.default.fileExists(atPath: configurationURL.path) else {
            throw GraphQLCodegenPluginError.missingConfiguration(configurationURL)
        }
        return configurationURL
    }
}

extension ExecutableConfigurationFile {
    fileprivate func validateForBuildPlugin() throws {
        guard input.schemaSource.scheme == nil else {
            throw GraphQLCodegenPluginError.unsupportedSchemaSource(input.schemaSource)
        }
        if output.schema.directory != nil {
            throw GraphQLCodegenPluginError.unsupportedOutputDirectory("schema")
        }
        if output.documents?.directory != nil {
            throw GraphQLCodegenPluginError.unsupportedOutputDirectory("documents")
        }
        if output.support.directory != nil {
            throw GraphQLCodegenPluginError.unsupportedOutputDirectory("support")
        }
    }
}

extension PluginContext {
    fileprivate var outputSchemaURL: URL {
        pluginWorkDirectoryURL.appending(path: "Schema.swift", directoryHint: .notDirectory)
    }

    fileprivate var outputSupportURL: URL {
        pluginWorkDirectoryURL.appending(path: "Support.swift", directoryHint: .notDirectory)
    }

    fileprivate func outputDocumentURL(for document: DocumentScanner.DocumentFile) -> URL {
        pluginWorkDirectoryURL.appending(
            path: document.relativePath + ".swift",
            directoryHint: .notDirectory
        )
    }
}

private enum GraphQLCodegenPluginError: Error, CustomStringConvertible {
    case missingConfiguration(URL)
    case unsupportedOutputDirectory(String)
    case unsupportedSchemaSource(URL)

    var description: String {
        switch self {
        case .missingConfiguration(let configuration):
            "Missing required GraphQL code generation configuration: \(configuration.path)"
        case .unsupportedOutputDirectory(let category):
            "Build plugins choose generated output directories; remove output.\(category).directory."
        case .unsupportedSchemaSource(let source):
            "Build plugins require a relative local schema file: \(source)"
        }
    }
}
