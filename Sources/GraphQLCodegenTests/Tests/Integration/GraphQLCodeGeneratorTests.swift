import Foundation
import GraphQLCodegen
import Testing

struct GraphQLCodeGeneratorTests {
    private static let currentDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Inside 'Integration'
    private let starwarsExampleDirectory = GraphQLCodeGeneratorTests
        .currentDirectory
        .deletingLastPathComponent() // Inside 'Tests'
        .deletingLastPathComponent() // Inside 'GraphQLCodegenTests'
        .deletingLastPathComponent() // Inside 'Sources'
        .appending(path: "StarwarsExample", directoryHint: .isDirectory)

    @Test
    func testGeneratesCodeForValidSchemaAndDocument() async throws {
        let generatedDirectory = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: generatedDirectory, withIntermediateDirectories: true)
        defer {
            // Best-effort test cleanup; retaining a temporary directory does not affect test behavior.
            try? FileManager.default.removeItem(at: generatedDirectory)
        }
        let operationsDirectory = generatedDirectory.appending(path: "Operations", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: operationsDirectory, withIntermediateDirectories: true)
        for operationFile in [
            "FavoriteEpisodeChangedSubscription.graphql",
            "HeroQuery.graphql",
            "SetFavoriteEpisodeMutation.graphql",
        ] {
            try FileManager.default.copyItem(
                at: starwarsExampleDirectory.appending(
                    path: "Operations/\(operationFile)",
                    directoryHint: .notDirectory
                ),
                to: operationsDirectory.appending(path: operationFile, directoryHint: .notDirectory)
            )
        }
        let scalarsDirectory = generatedDirectory.appending(
            path: "SchemaTypes/Scalars",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: scalarsDirectory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: starwarsExampleDirectory.appending(
                path: "SchemaTypes/Scalars/ID.graphqls.swift",
                directoryHint: .notDirectory
            ),
            to: scalarsDirectory.appending(path: "ID.graphqls.swift", directoryHint: .notDirectory)
        )
        try await Codegen(
            .configuration(
                input: .input(
                    schemaSource: .SDLSchemaFile(
                        starwarsExampleDirectory.appending(path: "schema.sdl", directoryHint: .notDirectory)
                    ),
                    documentDirectories: [operationsDirectory]
                ),
                output: .output(
                    schema: .schema(
                        directory: generatedDirectory.appending(path: "SchemaTypes", directoryHint: .isDirectory)
                    ),
                    documents: .documents(
                        directory: .directory(
                            operationsDirectory
                        )
                    ),
                    api: .api(
                        directory: generatedDirectory.appending(path: "API", directoryHint: .isDirectory),
                        HTTPSupport: .httpSupport(
                            enableGETQueries: true,
                            subscriptionSupport: true
                        )
                    )
                )
            )
        ).run()
        try OutputFile.allCases.forEach { outputFile in
            try verifyOutputFile(outputFile, generatedDirectory: generatedDirectory)
        }
    }

    @Test
    func generatedSubscriptionRequestsCannotEnableAutomaticPersistedOperations() async throws {
        let generatedDirectory = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: generatedDirectory, withIntermediateDirectories: true)
        defer {
            // Best-effort test cleanup; retaining a temporary directory does not affect test behavior.
            try? FileManager.default.removeItem(at: generatedDirectory)
        }

        let schemaURL = generatedDirectory.appending(path: "schema.graphqls", directoryHint: .notDirectory)
        try """
        type Query {
          version: String!
        }

        type Mutation {
          setVersion(version: String!): String!
        }

        type Subscription {
          ticks: Int!
        }
        """.write(to: schemaURL, atomically: true, encoding: .utf8)

        let operationsDirectory = generatedDirectory.appending(path: "Operations", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: operationsDirectory, withIntermediateDirectories: true)
        try """
        mutation SetVersion { setVersion(version: "2") }
        subscription Ticks { ticks }
        """.write(
            to: operationsDirectory.appending(path: "Ticks.graphql", directoryHint: .notDirectory),
            atomically: true,
            encoding: .utf8
        )

        let getAPI = generatedDirectory.appending(path: "GET/API", directoryHint: .isDirectory)
        try await generateSubscriptionAPI(
            schemaURL: schemaURL,
            operationsDirectory: operationsDirectory,
            apiDirectory: getAPI,
            enableGETQueries: true
        )
        let getRequest = try String(
            contentsOf: getAPI.appending(path: "HTTPSupport/GraphQLRequest.swift"),
            encoding: .utf8
        )
        let operationProtocols = try String(
            contentsOf: getAPI.appending(path: "HTTPSupport/GraphQLOperation.swift"),
            encoding: .utf8
        )
        #expect(operationProtocols.contains("protocol GraphQLSingleResponseOperation: GraphQLOperation"))
        #expect(operationProtocols.contains("protocol GraphQLQuery: GraphQLSingleResponseOperation"))
        #expect(operationProtocols.contains("protocol GraphQLMutation: GraphQLSingleResponseOperation"))
        #expect(operationProtocols.contains("protocol GraphQLSubscription: GraphQLOperation"))

        let urlSession = try String(
            contentsOf: getAPI.appending(path: "HTTPSupport/URLSession+GraphQL.swift"),
            encoding: .utf8
        )
        #expect(urlSession.contains("func request<Operation: GraphQLSingleResponseOperation>"))
        #expect(urlSession.contains("func subscribe<Subscription: GraphQLSubscription>"))

        #expect(getRequest.contains("enum SubscriptionStrategy"))
        #expect(getRequest.contains("strategy: SubscriptionStrategy = .GET()"))
        #expect(getRequest.contains(") throws where Operation: GraphQLSingleResponseOperation"))
        #expect(getRequest.contains("private init(\n        urlRequest: URLRequest"))
        let subscriptionStrategyStart = try #require(getRequest.range(of: "enum SubscriptionStrategy"))
        let subscriptionInitializerStart = try #require(
            getRequest.range(
                of: "/// Initializes a new `GraphQLRequest` with a subscription operation",
                range: subscriptionStrategyStart.upperBound..<getRequest.endIndex
            )
        )
        let subscriptionStrategy = getRequest[
            subscriptionStrategyStart.lowerBound..<subscriptionInitializerStart.lowerBound
        ]
        #expect(!subscriptionStrategy.contains("AutomaticPersistedOperation"))

        let postAPI = generatedDirectory.appending(path: "POST/API", directoryHint: .isDirectory)
        try await generateSubscriptionAPI(
            schemaURL: schemaURL,
            operationsDirectory: operationsDirectory,
            apiDirectory: postAPI,
            enableGETQueries: false
        )
        let postRequest = try String(
            contentsOf: postAPI.appending(path: "HTTPSupport/GraphQLRequest.swift"),
            encoding: .utf8
        )
        let subscriptionInitializer = try #require(
            postRequest.range(of: "/// Initializes a new `GraphQLRequest` with a subscription operation")
        )
        let subscriptionRequest = postRequest[subscriptionInitializer.lowerBound...]
        #expect(!subscriptionRequest.contains("automaticPersistedOperations"))
        #expect(subscriptionRequest.contains("automaticPersistedOperationPhase: nil"))
        #expect(subscriptionRequest.contains("self.persistedOperationRetry = nil"))

        for persistedOperations in [
            Configuration.Output.Documents.Operations.PersistedOperations.registered(
                manifestJSONFileOutput: generatedDirectory.appending(path: "manifest.json")
            ),
            nil,
        ] {
            let variantDirectory = generatedDirectory.appending(
                path: UUID().uuidString,
                directoryHint: .isDirectory
            )

            let getVariantAPI = variantDirectory.appending(path: "GET/API", directoryHint: .isDirectory)
            try await generateSubscriptionAPI(
                schemaURL: schemaURL,
                operationsDirectory: operationsDirectory,
                apiDirectory: getVariantAPI,
                enableGETQueries: true,
                persistedOperations: persistedOperations
            )
            let getRequest = try String(
                contentsOf: getVariantAPI.appending(path: "HTTPSupport/GraphQLRequest.swift"),
                encoding: .utf8
            )
            let getInitializer = try #require(
                getRequest.range(of: "/// Initializes a new `GraphQLRequest` with a subscription operation")
            )
            let getSubscriptionRequest = getRequest[getInitializer.lowerBound...]
            #expect(getRequest.contains("enum SubscriptionStrategy"))
            #expect(getSubscriptionRequest.contains("strategy: SubscriptionStrategy = .GET()"))
            #expect(!getSubscriptionRequest.contains("strategy: QueryStrategy"))

            let postVariantAPI = variantDirectory.appending(path: "POST/API", directoryHint: .isDirectory)
            try await generateSubscriptionAPI(
                schemaURL: schemaURL,
                operationsDirectory: operationsDirectory,
                apiDirectory: postVariantAPI,
                enableGETQueries: false,
                persistedOperations: persistedOperations
            )
            let postRequest = try String(
                contentsOf: postVariantAPI.appending(path: "HTTPSupport/GraphQLRequest.swift"),
                encoding: .utf8
            )
            let postInitializer = try #require(
                postRequest.range(of: "/// Initializes a new `GraphQLRequest` with a subscription operation")
            )
            #expect(!postRequest[postInitializer.lowerBound...].contains("try self.init("))
        }
    }

    private func generateSubscriptionAPI(
        schemaURL: URL,
        operationsDirectory: URL,
        apiDirectory: URL,
        enableGETQueries: Bool,
        persistedOperations: Configuration.Output.Documents.Operations.PersistedOperations? = .automatic
    ) async throws {
        try await Codegen(
            .configuration(
                input: .input(
                    schemaSource: .SDLSchemaFile(schemaURL),
                    documentDirectories: [operationsDirectory]
                ),
                output: .output(
                    schema: .schema(
                        directory: apiDirectory
                            .deletingLastPathComponent()
                            .appending(path: "SchemaTypes", directoryHint: .isDirectory)
                    ),
                    documents: .documents(
                        operations: .operations(persistedOperations: persistedOperations)
                    ),
                    api: .api(
                        directory: apiDirectory,
                        HTTPSupport: .httpSupport(
                            enableGETQueries: enableGETQueries,
                            subscriptionSupport: true
                        )
                    )
                )
            )
        ).run()
    }

    private func verifyOutputFile(_ outputFile: OutputFile, generatedDirectory: URL) throws {
        let expectedFileURL = starwarsExampleDirectory.appending(
            path: outputFile.relativePath,
            directoryHint: .notDirectory
        )
        #expect(FileManager.default.fileExists(atPath: expectedFileURL.path(percentEncoded: false)))
        let outputFileURL = generatedDirectory.appending(
            path: outputFile.relativePath,
            directoryHint: .notDirectory
        )
        #expect(FileManager.default.fileExists(atPath: outputFileURL.path(percentEncoded: false)))
        let expectedFileContents = try String(contentsOf: expectedFileURL, encoding: .utf8)
        let outputFileContents = try String(contentsOf: outputFileURL, encoding: .utf8)
        #expect(expectedFileContents == outputFileContents)
    }
}

enum OutputFile: String, CaseIterable {
    case DefaultEncoders
    case Encoders
    case FavoriteEpisodeChangedSubscription
    case GraphQLOperation
    case GraphQLRequest
    case URLSessionGraphQL
    case AnyEncodable
    case GraphQLEnum
    case GraphQLError
    case GraphQLHasDefault
    case GraphQLNullable
    case GraphQLResponse
    case JSONValue
    case HeroQuery
    case SetFavoriteEpisodeMutation
    case Episode
    case ID

    var relativePath: String {
        switch self {
        case .DefaultEncoders: "API/HTTPSupport/DefaultEncoders.swift"
        case .Encoders: "API/HTTPSupport/Encoders.swift"
        case .FavoriteEpisodeChangedSubscription:
            "Operations/FavoriteEpisodeChangedSubscription.graphql.swift"
        case .GraphQLOperation: "API/HTTPSupport/GraphQLOperation.swift"
        case .GraphQLRequest: "API/HTTPSupport/GraphQLRequest.swift"
        case .URLSessionGraphQL: "API/HTTPSupport/URLSession+GraphQL.swift"
        case .AnyEncodable: "API/AnyEncodable.swift"
        case .GraphQLEnum: "API/GraphQLEnum.swift"
        case .GraphQLError: "API/GraphQLError.swift"
        case .GraphQLHasDefault: "API/GraphQLHasDefault.swift"
        case .GraphQLNullable: "API/GraphQLNullable.swift"
        case .GraphQLResponse: "API/GraphQLResponse.swift"
        case .JSONValue: "API/JSONValue.swift"
        case .HeroQuery: "Operations/HeroQuery.graphql.swift"
        case .SetFavoriteEpisodeMutation: "Operations/SetFavoriteEpisodeMutation.graphql.swift"
        case .Episode: "SchemaTypes/Enums/Episode.graphqls.swift"
        case .ID: "SchemaTypes/Scalars/ID.graphqls.swift"
        }
    }
}
