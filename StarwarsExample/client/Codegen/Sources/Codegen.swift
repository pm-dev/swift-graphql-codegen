import Foundation
import GraphQLCodegen

@main
enum StarwarsCodegen {
    private static let exampleDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static let generatedDirectory = exampleDirectory
        .appending(path: "client/Packages/GraphQL/Source/Generated", directoryHint: .isDirectory)

    private static let schemaURL = exampleDirectory
        .appending(path: "server/src/schema.graphql", directoryHint: .notDirectory)

    static func main() async throws {
        try await Codegen(
            .configuration(
                input: .input(
                    schemaSource: .SDLSchemaFile(schemaURL),
                    documentDirectories: [exampleDirectory.appending(path: "client/iOS/GraphQL", directoryHint: .isDirectory)]
                ),
                output: .output(
                    schema: .schema(
                        directory: generatedDirectory,
                        scalars: .scalars(
                            scalarMapping: [
                                "ID": .scalar(typeName: "GraphQLID"),
                            ]
                        ),
                        enums: .enums(caseConversion: .conversion(from: .macro, to: .lowerCamel)),
                        accessLevel: .public
                    ),
                    documents: .documents(
                        importedModules: ["GraphQL"]
                    ),
                    support: .support(
                        directory: generatedDirectory,
                        accessLevel: .public,
                        HTTPSupport: .httpSupport(
                            enableGETQueries: true,
                            persistedOperations: .automatic,
                            subscriptionSupport: true
                        )
                    )
                )
            )
        ).run()
    }
}
