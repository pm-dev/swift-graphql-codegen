import Foundation
import GraphQLCodegen

@main
enum GraphQLCodegenCommand {
    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count == 2 || arguments.count == 4,
              arguments[0] == "--file-configuration",
              arguments.count == 2 || arguments[2] == "--output-directory" else {
            throw CommandError.invalidArguments
        }

        let configurationURL = URL(fileURLWithPath: arguments[1]).standardizedFileURL
        let outputDirectory = arguments.count == 4
            ? URL(fileURLWithPath: arguments[3]).standardizedFileURL
            : nil
        let configurationFile = try ExecutableConfigurationFile.at(configurationURL)
        let configuration = try configurationFile.configuration(
            relativeTo: configurationURL.deletingLastPathComponent(),
            outputDirectory: outputDirectory
        )
        try await Codegen(configuration).run()
    }
}

extension GraphQLCodegenCommand {
    private enum CommandError: Error, CustomStringConvertible {
        case invalidArguments

        var description: String {
            "Usage: graphql-codegen --file-configuration <configuration-file> [--output-directory <directory>]"
        }
    }
}
