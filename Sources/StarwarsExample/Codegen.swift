import Foundation
import GraphQLCodegen

@main
struct StarwarsCodegen {
    private static let currentFileDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

    static func main() async throws {
        try await Codegen(
            .configuration(
                input: .input(
                    schemaSource: .SDLSchemaFile(
                        currentFileDirectory.appending(path: "schema.sdl", directoryHint: .notDirectory)
                    ),
                    documentDirectories: [currentFileDirectory.appending(path: "Operations", directoryHint: .isDirectory)]
                ),
                output: .output(
                    schema: .schema(
                        directory: currentFileDirectory.appending(path: "SchemaTypes", directoryHint: .isDirectory)
                    ),
                    api: .api(
                        directory: currentFileDirectory.appending(path: "API", directoryHint: .isDirectory),
                        HTTPSupport: .httpSupport(enableGETQueries: true)
                    )
                )
            )
        ).run()
    }
}
