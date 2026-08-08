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
        .deletingLastPathComponent() // Inside root 'Tests'
        .deletingLastPathComponent() // Inside the package root
        .appending(path: "Examples/StarwarsExample/Sources/StarwarsExample", directoryHint: .isDirectory)

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
                        directory: generatedDirectory.appending(path: "SchemaTypes", directoryHint: .isDirectory),
                        enums: .enums(caseConversion: .conversion(from: .macro, to: .lowerCamel))
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
        let urlSessionSource = try String(
            contentsOf: generatedDirectory.appending(
                path: OutputFile.URLSessionGraphQL.relativePath,
                directoryHint: .notDirectory
            ),
            encoding: .utf8
        )
        #expect(urlSessionSource.contains("maximumLineByteCount"))
        #expect(urlSessionSource.contains("requires version 26 or newer"))
        #expect(urlSessionSource.contains("UTF8Span(validating: buffer.span)"))
        #expect(!urlSessionSource.contains("String(bytes: buffer, encoding: .utf8)"))
    }

    @Test
    func preservesConditionalityAcrossNestedTypeConditions() async throws {
        let output = try await runCodegen(
            document: """
            query Hero {
              hero {
                ... on Human {
                  ... on Character {
                    name
                  }
                }
              }
            }
            """,
            schema: """
            type Query { hero: Character! }
            interface Character { name: String! }
            type Human implements Character { name: String! }
            type Droid implements Character { name: String! }
            """
        )

        #expect(output.contains("let name: String?"))
    }

    @Test
    func requiresTypenameForNamedFragmentSpreadInsideConditionalType() async {
        await expectCodegenError(containing: "'__typename' needed in selection set under the 'hero' field") {
            try await runCodegen(
                document: """
                fragment CharacterFields on Character { name }

                query Hero {
                  hero {
                    ... on Human {
                      ...CharacterFields
                    }
                  }
                }
                """,
                schema: """
                type Query { hero: Character! }
                interface Character { name: String! }
                type Human implements Character { name: String! }
                type Droid implements Character { name: String! }
                """
            )
        }
    }

    @Test
    func preservesConditionalityForNamedFragmentSpread() async throws {
        let output = try await runCodegen(
            document: """
            fragment CharacterFields on Character { name }

            query Hero {
              hero {
                __typename
                ... on Human {
                  ...CharacterFields
                }
              }
            }
            """,
            schema: """
            type Query { hero: Character! }
            interface Character { name: String! }
            type Human implements Character { name: String! }
            type Droid implements Character { name: String! }
            """
        )

        #expect(output.contains("let __CharacterFields: CharacterFields?"))
        #expect(
            output.contains(
                "__CharacterFields = __typename == \"Human\" ? try CharacterFields(from: decoder) : nil"
            )
        )
    }

    @Test
    func rejectsAliasesThatProduceConflictingNestedTypeNames() async {
        await expectCodegenError(containing: "conflicting Swift nested type names") {
            try await runCodegen(
                document: """
                query Viewer {
                  viewer: viewer(id: "1") { name }
                  Viewer: viewer(id: "2") { name }
                }
                """,
                schema: """
                type Query { viewer(id: ID!): Viewer! }
                type Viewer { name: String! }
                """
            )
        }
    }

    @Test
    func reportsValidationErrorsForMultipleOperations() async {
        await expectCodegenError(
            containing: [
                "Operation: First",
                "Cannot query field \"first\"",
                "Operation: Second",
                "Cannot query field \"second\"",
            ]
        ) {
            try await runCodegen(
                document: """
                query First { first }
                query Second { second }
                """,
                schema: """
                type Query { value: String! }
                """
            )
        }
    }

    @Test
    func rejectsFieldAndFragmentThatProduceConflictingTypeNames() async {
        await expectCodegenError(containing: "response key and fragment name") {
            try await runCodegen(
                document: """
                query Viewer {
                  foo: viewer { name }
                  ...foo
                }
                fragment foo on Query { version }
                """,
                schema: """
                type Query {
                  viewer: Viewer!
                  version: String!
                }
                type Viewer { name: String! }
                """
            )
        }
    }

    @Test
    func rejectsResponseKeyThatConflictsWithCodingKeys() async {
        await expectCodegenError(containing: "conflicts with a generated Swift type name") {
            try await runCodegen(
                document: """
                query Viewer {
                  codingKeys: viewer { name }
                }
                """,
                schema: """
                type Query { viewer: Viewer! }
                type Viewer { name: String! }
                """
            )
        }
    }

    @Test
    func rejectsSchemaTypesShadowedByFixedOperationTypes() async {
        let collisions = [
            (
                document: "query Viewer { codingKey }",
                schema: """
                scalar CodingKey
                type Query { codingKey: CodingKey! }
                """
            ),
            (
                document: "query Viewer { data }",
                schema: """
                enum Data { VALUE }
                type Query { data: Data! }
                """
            ),
            (
                document: "query Viewer($variables: Variables!) { value(variables: $variables) }",
                schema: """
                input Variables { value: String! }
                type Query { value(variables: Variables!): String! }
                """
            ),
        ]

        for collision in collisions {
            await expectCodegenError(containing: "shadows a type referenced by generated code") {
                try await runCodegen(document: collision.document, schema: collision.schema)
            }
        }
    }

    @Test
    func preservesCallerControlledConformances() async throws {
        let output = try await runCodegen(
            document: """
            query Viewer {
              sendable: viewer { name }
            }
            """,
            schema: """
            type Query { viewer: Viewer! }
            type Viewer { name: String! }
            """,
            responseDataConformances: ["Swift.Decodable", "JSONValue", "@unchecked Swift.Sendable"]
        )

        #expect(output.contains("struct Sendable: Swift.Decodable, JSONValue, @unchecked Swift.Sendable"))
    }

    @Test
    func rejectsConflictingTopLevelTypeNames() async {
        await expectCodegenError(containing: "conflicting top-level Swift type names") {
            try await runCodegen(
                document: """
                query Viewer { value }
                """,
                schema: """
                enum ViewerQuery { VALUE }
                type Query { value: ViewerQuery! }
                """
            )
        }
    }

    @Test
    func rejectsEnumCaseNamesThatCollideAfterConversion() async {
        await expectCodegenError(
            containing: [
                "GraphQL enum values produce conflicting Swift case names after case conversion",
                "NORTH_WEST",
                "NORTH__WEST",
                "Swift case name: northWest",
            ]
        ) {
            try await runCodegen(
                document: "query Compass { direction }",
                schema: """
                enum Direction {
                  NORTH_WEST
                  NORTH__WEST
                }
                type Query { direction: Direction! }
                """,
                enumCaseConversion: .conversion(from: .macro, to: .lowerCamel)
            )
        }
    }

    @Test
    func rejectsSchemaTypeNamedAfterGeneratedAPIType() async {
        for typeName in ["GraphQLSingleResponseOperation", "PersistedOperationRetry"] {
            await expectCodegenError(containing: "conflicting top-level Swift type names") {
                try await runCodegen(
                    document: """
                    query Viewer { value }
                    """,
                    schema: """
                    scalar \(typeName)
                    type Query { value: \(typeName)! }
                    """
                )
            }
        }
    }

    @Test
    func acceptsCaseDistinctScalarResponseKeys() async throws {
        try await runCodegen(
            document: """
            query Viewer {
              value
              Value
            }
            """,
            schema: """
            type Query {
              value: String!
              Value: String!
            }
            """
        )
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

    @discardableResult
    private func runCodegen(
        document: String,
        schema: String,
        enumCaseConversion: Configuration.Output.Schema.Enums.CaseConversion? = nil,
        responseDataConformances: [String] = ["Decodable", "Sendable", "Hashable"]
    ) async throws -> String {
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
        let documentURL = operationsDirectory.appending(path: "Viewer.graphql", directoryHint: .notDirectory)
        try document.write(to: documentURL, atomically: true, encoding: .utf8)
        let schemaURL = generatedDirectory.appending(path: "schema.graphqls", directoryHint: .notDirectory)
        try schema.write(to: schemaURL, atomically: true, encoding: .utf8)
        try await Codegen(
            .configuration(
                input: .input(
                    schemaSource: .SDLSchemaFile(schemaURL),
                    documentDirectories: [operationsDirectory]
                ),
                output: .output(
                    schema: .schema(
                        directory: generatedDirectory.appending(path: "SchemaTypes", directoryHint: .isDirectory),
                        enums: .enums(caseConversion: enumCaseConversion)
                    ),
                    documents: .documents(
                        directory: .directory(operationsDirectory),
                        operations: .operations(
                            responseData: .responseData(conformances: responseDataConformances)
                        )
                    ),
                    api: .api(
                        directory: generatedDirectory.appending(path: "API", directoryHint: .isDirectory),
                        HTTPSupport: .httpSupport()
                    )
                )
            )
        ).run()
        return try String(contentsOf: documentURL.appendingPathExtension("swift"), encoding: .utf8)
    }

    private func expectCodegenError(
        containing expectedDescription: String,
        operation: () async throws -> Void
    ) async {
        await expectCodegenError(containing: [expectedDescription], operation: operation)
    }

    private func expectCodegenError(
        containing expectedDescriptions: [String],
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            Issue.record("Expected code generation to fail")
        } catch {
            for expectedDescription in expectedDescriptions {
                #expect(String(describing: error).contains(expectedDescription))
            }
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
