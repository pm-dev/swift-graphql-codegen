import Foundation
import PackagePlugin

@main
struct GraphQLCodegenPlugin: BuildToolPlugin {
    func createBuildCommands(
        context: PluginContext,
        target: any Target
    ) async throws -> [Command] {
        let configurationURL = target.directoryURL.appending(
            path: "graphql-codegen.json",
            directoryHint: .notDirectory
        )
        guard FileManager.default.fileExists(atPath: configurationURL.path) else {
            throw PluginError.missingConfiguration(configurationURL)
        }

        let configuration = try JSONDecoder().decode(
            InputConfiguration.self,
            from: Data(contentsOf: configurationURL)
        )
        let schemaURL = target.directoryURL.appending(
            path: configuration.schema.path,
            directoryHint: .notDirectory
        ).standardizedFileURL
        let documentDirectories = configuration.documentDirectories.map { path in
            target.directoryURL.appending(path: path, directoryHint: .isDirectory)
                .standardizedFileURL
        }
        let documentURLs = try Set(documentDirectories.flatMap(graphQLDocuments(in:)))
            .sorted { $0.path < $1.path }
        let outputURLs = OutputFile.allCases.map { output in
            context.pluginWorkDirectoryURL.appending(
                path: output.rawValue,
                directoryHint: .notDirectory
            )
        }
        let executableURL = try context.tool(named: "graphql-codegen").url
        return [
            .buildCommand(
                displayName: "Generate GraphQL sources for \(target.name)",
                executable: executableURL,
                arguments: [configurationURL.path, context.pluginWorkDirectoryURL.path],
                inputFiles: [configurationURL, schemaURL] + documentURLs,
                outputFiles: outputURLs
            ),
        ]
    }

    private func graphQLDocuments(in directory: URL) throws -> [URL] {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: .skipsHiddenFiles
        ) else {
            throw PluginError.failedToEnumerateDocumentDirectory(directory)
        }
        var documents: [URL] = []
        for case let url as URL in enumerator
            where try url.resourceValues(forKeys: resourceKeys).isRegularFile == true &&
            url.pathExtension == "graphql" {
            documents.append(url.standardizedFileURL)
        }
        return documents.sorted { $0.path < $1.path }
    }
}

extension GraphQLCodegenPlugin {
    private struct InputConfiguration: Decodable {
        struct Schema: Decodable {
            let path: String
        }

        let schema: Schema
        let documentDirectories: [String]
    }

    private enum OutputFile: String, CaseIterable {
        case api = "GraphQLAPI.generated.swift"
        case documents = "GraphQLDocuments.generated.swift"
        case schema = "GraphQLSchema.generated.swift"
    }

    private enum PluginError: Error, CustomStringConvertible {
        case failedToEnumerateDocumentDirectory(URL)
        case missingConfiguration(URL)

        var description: String {
            switch self {
            case .failedToEnumerateDocumentDirectory(let directory):
                "Failed to enumerate GraphQL document directory: \(directory.path)"
            case .missingConfiguration(let configuration):
                "Missing required GraphQL code generation configuration: \(configuration.path)"
            }
        }
    }
}
