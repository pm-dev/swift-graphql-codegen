import Foundation
import GraphQLCodegen
import Testing

struct GraphQLCodeGeneratorTests {
    private static let testsDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Inside 'Integration'
        .deletingLastPathComponent() // Inside 'Tests'
        .deletingLastPathComponent() // Inside root 'Tests'

    private let definitionsDirectory = GraphQLCodeGeneratorTests.testsDirectory
        .appending(path: "Fixtures/Definitions/Integration", directoryHint: .isDirectory)
    private let expectedDirectory = GraphQLCodeGeneratorTests.testsDirectory
        .appending(path: "Fixtures/Generated", directoryHint: .isDirectory)

    @Test
    func preservesExecutableDescriptionsAsDocumentation() async throws {
        let output = try await runCodegen(
            document: #"""
            """
            Loads the **viewer**.

            Use this operation for profile screens.
            """
            query Viewer(
              "Include the viewer's `name`."
              $includeName: Boolean!
            ) {
              viewer {
                ...ViewerFields
              }
            }

            "Shared viewer fields."
            fragment ViewerFields on Viewer {
              name @include(if: $includeName)
            }
            """#,
            schema: """
            type Query { viewer: Viewer! }
            type Viewer { name: String! }
            """
        )

        #expect(
            output.contains(
                "/// Loads the **viewer**.\n" +
                    "/// \n" +
                    "/// Use this operation for profile screens.\n" +
                    "struct ViewerQuery"
            )
        )
        #expect(
            output.contains(
                "    /// - Parameters:\n" +
                    "    ///   - includeName: Include the viewer's `name`.\n" +
                    "    init("
            )
        )
        #expect(
            output.contains(
                "        /// Include the viewer's `name`.\n" +
                    "        let includeName: Bool"
            )
        )
        #expect(output.contains("""
        /// Shared viewer fields.
        struct ViewerFields
        """))
        #expect(
            output.contains(
                "static let document = #\"\"\"\n" +
                    "    query Viewer($includeName:Boolean!){viewer{...ViewerFields}}" +
                    "fragment ViewerFields on Viewer{name@include(if:$includeName)}"
            )
        )
        #expect(!output.contains("minifiedDocument"))
    }

    @Test
    func preservesDocumentFormattingWhenMinificationIsDisabled() async throws {
        let output = try await runCodegen(
            document: """
            query Viewer {
              viewer {
                id
                name
              }
            }
            """,
            schema: """
            type Query { viewer: Viewer! }
            type Viewer { id: ID!, name: String! }
            """,
            minifyDocument: false
        )

        #expect(
            output.contains(
                ##"""
                static let document = #"""
                    query Viewer {
                      viewer {
                        id
                        name
                      }
                    }
                    """#
                """##
            )
        )
        #expect(!output.contains("query Viewer{viewer{id name}}"))
    }

    @Test
    func generatesCodeForValidSchemaAndDocument() async throws {
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
            "NodeQuery.graphql",
            "SetStateMutation.graphql",
            "StateChangedSubscription.graphql",
        ] {
            try FileManager.default.copyItem(
                at: definitionsDirectory.appending(
                    path: "Operations/\(operationFile)",
                    directoryHint: .notDirectory
                ),
                to: operationsDirectory.appending(path: operationFile, directoryHint: .notDirectory)
            )
        }
        try await Codegen(
            .configuration(
                input: .input(
                    schemaSource: .SDLSchemaFile(
                        definitionsDirectory.appending(
                            path: "schema.sdl",
                            directoryHint: .notDirectory
                        )
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
                    support: .support(
                        directory: generatedDirectory.appending(path: "Support", directoryHint: .isDirectory),
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
        let supportSource = try String(
            contentsOf: generatedDirectory.appending(
                path: OutputFile.Support.relativePath,
                directoryHint: .notDirectory
            ),
            encoding: .utf8
        )
        #expect(supportSource.contains("maximumLineByteCount"))
        #expect(supportSource.contains("requires version 26 or newer"))
        #expect(supportSource.contains("UTF8Span(validating: buffer.span)"))
        #expect(!supportSource.contains("String(bytes: buffer, encoding: .utf8)"))
    }

    @Test
    func usesCaseLevelIndirectionForRecursiveInputObjects() async throws {
        let output = try await runCodegen(
            document: """
            query Viewer($input: RecursiveInput) {
              value(input: $input)
            }
            """,
            schema: """
            input RecursiveInput {
              nested: RecursiveInput
            }
            type Query { value(input: RecursiveInput): String! }
            """,
            outputRelativePath: "Support/Support.swift"
        )

        #expect(!output.contains("indirect enum GraphQLNullable"))
        #expect(output.contains("indirect case value(T)"))
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
                "Direction.NORTH_WEST",
                "Direction.NORTH__WEST",
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
    func rejectsSchemaTypeNamedAfterGeneratedSupportType() async {
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

        let getSupport = generatedDirectory.appending(path: "GET/Support", directoryHint: .isDirectory)
        try await generateSubscriptionSupport(
            schemaURL: schemaURL,
            operationsDirectory: operationsDirectory,
            supportDirectory: getSupport,
            enableGETQueries: true
        )
        let getRequest = try String(
            contentsOf: getSupport.appending(path: "Support.swift"),
            encoding: .utf8
        )
        #expect(getRequest.contains("protocol GraphQLSingleResponseOperation: GraphQLOperation"))
        #expect(getRequest.contains("protocol GraphQLQuery: GraphQLSingleResponseOperation"))
        #expect(getRequest.contains("protocol GraphQLMutation: GraphQLSingleResponseOperation"))
        #expect(getRequest.contains("protocol GraphQLSubscription: GraphQLOperation"))
        #expect(getRequest.contains("func request<Operation: GraphQLSingleResponseOperation>"))
        #expect(getRequest.contains("func subscribe<Subscription: GraphQLSubscription>"))

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

        let postSupport = generatedDirectory.appending(path: "POST/Support", directoryHint: .isDirectory)
        try await generateSubscriptionSupport(
            schemaURL: schemaURL,
            operationsDirectory: operationsDirectory,
            supportDirectory: postSupport,
            enableGETQueries: false
        )
        let postRequest = try String(
            contentsOf: postSupport.appending(path: "Support.swift"),
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
            Configuration.Output.Support.HTTPSupport.PersistedOperations.registered(),
            Configuration.Output.Support.HTTPSupport.PersistedOperations.registered(
                allowUnregisteredOperations: true
            ),
            nil,
        ] {
            let variantDirectory = generatedDirectory.appending(
                path: UUID().uuidString,
                directoryHint: .isDirectory
            )

            let getVariantSupport = variantDirectory.appending(path: "GET/Support", directoryHint: .isDirectory)
            try await generateSubscriptionSupport(
                schemaURL: schemaURL,
                operationsDirectory: operationsDirectory,
                supportDirectory: getVariantSupport,
                enableGETQueries: true,
                persistedOperations: persistedOperations,
                minifyDocument: false
            )
            let getRequest = try String(
                contentsOf: getVariantSupport.appending(path: "Support.swift"),
                encoding: .utf8
            )
            let getInitializer = try #require(
                getRequest.range(of: "/// Initializes a new `GraphQLRequest` with a subscription operation")
            )
            let getSubscriptionRequest = getRequest[getInitializer.lowerBound...]
            #expect(getRequest.contains("enum SubscriptionStrategy"))
            #expect(getSubscriptionRequest.contains("strategy: SubscriptionStrategy = .GET()"))
            #expect(!getSubscriptionRequest.contains("strategy: QueryStrategy"))

            let postVariantSupport = variantDirectory.appending(path: "POST/Support", directoryHint: .isDirectory)
            try await generateSubscriptionSupport(
                schemaURL: schemaURL,
                operationsDirectory: operationsDirectory,
                supportDirectory: postVariantSupport,
                enableGETQueries: false,
                persistedOperations: persistedOperations,
                minifyDocument: false
            )
            let postRequest = try String(
                contentsOf: postVariantSupport.appending(path: "Support.swift"),
                encoding: .utf8
            )
            let postInitializer = try #require(
                postRequest.range(of: "/// Initializes a new `GraphQLRequest` with a subscription operation")
            )
            #expect(!postRequest[postInitializer.lowerBound...].contains("try self.init("))

            if case .registered(let allowUnregisteredOperations) = persistedOperations {
                let generatedOperations = try String(
                    contentsOf: operationsDirectory.appending(path: "Ticks.graphql.swift"),
                    encoding: .utf8
                )
                #expect(generatedOperations.contains("static let document"))
                #expect(!generatedOperations.contains("static let hash"))

                #expect(getRequest.contains("static var document: String { get }"))
                #expect(!getRequest.contains("static var hash: String { get }"))
                #expect(
                    getRequest.contains("useRegisteredOperation: Bool = true") == allowUnregisteredOperations
                )
                #expect(
                    postRequest.contains("useRegisteredOperation: Bool = true") == allowUnregisteredOperations
                )

                for supportDirectory in [getVariantSupport, postVariantSupport] {
                    let supportSource = try String(
                        contentsOf: supportDirectory.appending(path: "Support.swift"),
                        encoding: .utf8
                    )
                    #expect(supportSource.contains("import CryptoKit"))
                    #expect(supportSource.contains("persistedOperationHash(Operation.document)"))
                    #expect(supportSource.contains("if useRegisteredOperation") == allowUnregisteredOperations)
                    #expect(
                        supportSource.contains("self.query = useRegisteredOperation ? nil : Operation.document") ==
                            allowUnregisteredOperations
                    )
                    #expect(!supportSource.contains("Operation.hash"))
                    #expect(
                        supportSource.contains("useRegisteredOperation: Bool") == allowUnregisteredOperations
                    )
                }
            }
        }
    }

    @discardableResult
    private func runCodegen(
        document: String,
        schema: String,
        enumCaseConversion: Configuration.Output.Schema.Enums.CaseConversion? = nil,
        minifyDocument: Bool = true,
        outputRelativePath: String = "Operations/Viewer.graphql.swift",
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
                            minifyDocument: minifyDocument,
                            responseData: .responseData(conformances: responseDataConformances)
                        )
                    ),
                    support: .support(
                        directory: generatedDirectory.appending(path: "Support", directoryHint: .isDirectory),
                        HTTPSupport: .httpSupport()
                    )
                )
            )
        ).run()
        return try String(
            contentsOf: generatedDirectory.appending(path: outputRelativePath, directoryHint: .notDirectory),
            encoding: .utf8
        )
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

    private func generateSubscriptionSupport(
        schemaURL: URL,
        operationsDirectory: URL,
        supportDirectory: URL,
        enableGETQueries: Bool,
        persistedOperations: Configuration.Output.Support.HTTPSupport.PersistedOperations? = .automatic,
        minifyDocument: Bool = true
    ) async throws {
        try await Codegen(
            .configuration(
                input: .input(
                    schemaSource: .SDLSchemaFile(schemaURL),
                    documentDirectories: [operationsDirectory]
                ),
                output: .output(
                    schema: .schema(
                        directory: supportDirectory
                            .deletingLastPathComponent()
                            .appending(path: "SchemaTypes", directoryHint: .isDirectory)
                    ),
                    documents: .documents(
                        operations: .operations(minifyDocument: minifyDocument)
                    ),
                    support: .support(
                        directory: supportDirectory,
                        HTTPSupport: .httpSupport(
                            enableGETQueries: enableGETQueries,
                            persistedOperations: persistedOperations,
                            subscriptionSupport: true
                        )
                    )
                )
            )
        ).run()
    }

    private func verifyOutputFile(_ outputFile: OutputFile, generatedDirectory: URL) throws {
        let expectedFileURL = expectedDirectory.appending(
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
    case StateChangedSubscription
    case NodeQuery
    case SetStateMutation
    case Schema
    case Support

    var relativePath: String {
        switch self {
        case .StateChangedSubscription:
            "Operations/StateChangedSubscription.graphql.swift"
        case .NodeQuery: "Operations/NodeQuery.graphql.swift"
        case .SetStateMutation: "Operations/SetStateMutation.graphql.swift"
        case .Schema: "SchemaTypes/Schema.swift"
        case .Support: "Support/Support.swift"
        }
    }
}
