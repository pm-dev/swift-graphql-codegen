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
                    schemaSource: .file(.SDL(schemaURL)),
                    documentDirectories: [sourceDirectory.appending(path: "Operations", directoryHint: .isDirectory)]
                ),
                output: .output(
                    schema: .schema(
                        directory: sourceDirectory.appending(path: "Schema", directoryHint: .isDirectory),
                        enums: .enums(caseConversion: .conversion(from: .macro, to: .lowerCamel)),
                        accessLevel: .public
                    ),
                    documents: .documents(accessLevel: .public),
                    api: .api(
                        directory: sourceDirectory.appending(path: "Utility", directoryHint: .isDirectory),
                        accessLevel: .public,
                        HTTPSupport: .httpSupport(
                            enableGETQueries: true,
                            persistedOperations: .registered(
                                manifestJSONFileOutput: exampleDirectory.appending(
                                    path: "server/src/registered-operations.generated.json",
                                    directoryHint: .notDirectory
                                )
                            ),
                            subscriptionSupport: true
                        )
                    )
                )
            )
        ).run()
    }
}
