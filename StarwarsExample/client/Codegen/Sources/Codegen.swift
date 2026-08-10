import Foundation
import GraphQLCodegen

@main
enum StarwarsCodegen {
    private static let exampleDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static let sourceDirectory = exampleDirectory
        .appending(path: "client/Packages/GraphQL", directoryHint: .isDirectory)

    private static let schemaURL = exampleDirectory
        .appending(path: "server/src/schema.graphql", directoryHint: .notDirectory)

    static func main() async throws {
        try await Codegen(
            .configuration(
                input: .input(
                    schemaSource: .SDLSchemaFile(schemaURL),
                    documentDirectories: [sourceDirectory.appending(path: "Operations", directoryHint: .isDirectory)]
                ),
                output: .output(
                    schema: .schema(
                        directory: sourceDirectory.appending(path: "Schema", directoryHint: .isDirectory),
                        enums: .enums(caseConversion: .conversion(from: .macro, to: .lowerCamel)),
                        accessLevel: .public
                    ),
                    documents: .documents(accessLevel: .public),
                    support: .support(
                        directory: sourceDirectory.appending(path: "Support", directoryHint: .isDirectory),
                        accessLevel: .public,
                        HTTPSupport: .httpSupport(
                            enableGETQueries: true,
                            subscriptionSupport: true
                        )
                    )
                )
            )
        ).run()
    }
}
