import Foundation
import GraphQLCodegen

@main
enum StarwarsCodegen {
    private static let clientDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // In Codegen
        .deletingLastPathComponent() // In Sources
        .deletingLastPathComponent() // In GraphQL
        .deletingLastPathComponent() // In Packages
        .deletingLastPathComponent() // In client

    private static let generatedDirectory = clientDirectory
        .appending(path: "Packages/GraphQL/Sources/GraphQL/Generated", directoryHint: .isDirectory)

    private static let schemaURL = clientDirectory
        .deletingLastPathComponent()
        .appending(path: "server/src/schema.graphql", directoryHint: .notDirectory)

    private static let registeredOperationsManifestURL = schemaURL
        .deletingLastPathComponent()
        .appending(path: "registered-operations.generated.json", directoryHint: .notDirectory)

    static func main() async throws {
        let codegen = Codegen(
            .configuration(
                input: .input(
                    schemaSource: .SDLSchemaFile(schemaURL),
                    documentDirectories: [
                        clientDirectory.appending(path: "iOS/GraphQL", directoryHint: .isDirectory),
                    ]
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
                            persistedOperations: .registered(allowUnregisteredOperations: true),
                            subscriptionSupport: true
                        )
                    )
                )
            )
        )

        try await codegen.run()

        // Normally you would run this step only for a release
        try await codegen.generatePersistedOperationManifestFile(at: registeredOperationsManifestURL)
    }
}
