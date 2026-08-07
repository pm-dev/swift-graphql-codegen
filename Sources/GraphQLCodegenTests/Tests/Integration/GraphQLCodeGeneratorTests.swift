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
        try FileManager.default.copyItem(
            at: starwarsExampleDirectory.appending(
                path: "Operations/HeroQuery.graphql",
                directoryHint: .notDirectory
            ),
            to: operationsDirectory.appending(path: "HeroQuery.graphql", directoryHint: .notDirectory)
        )
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
                        HTTPSupport: .httpSupport(enableGETQueries: true)
                    )
                )
            )
        ).run()
        try OutputFile.allCases.forEach { outputFile in
            try verifyOutputFile(outputFile, generatedDirectory: generatedDirectory)
        }
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
    case Episode
    case ID

    var relativePath: String {
        switch self {
        case .DefaultEncoders: "API/HTTPSupport/DefaultEncoders.swift"
        case .Encoders: "API/HTTPSupport/Encoders.swift"
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
        case .Episode: "SchemaTypes/Enums/Episode.graphqls.swift"
        case .ID: "SchemaTypes/Scalars/ID.graphqls.swift"
        }
    }
}
