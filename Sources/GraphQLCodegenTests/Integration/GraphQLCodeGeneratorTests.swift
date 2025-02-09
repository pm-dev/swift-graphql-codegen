import Foundation
@testable import GraphQLCodegen
import Testing

struct GraphQLCodeGeneratorTests {
    private static let currentDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Inside 'Integration'
    private let starwarsExampleDirectory = GraphQLCodeGeneratorTests
        .currentDirectory
        .deletingLastPathComponent() // Inside 'GraphQLCodegenTests'
        .deletingLastPathComponent() // Inside 'Sources'
        .appending(path: "StarwarsExample", directoryHint: .isDirectory)
    private let expectedOutputDirectory = GraphQLCodeGeneratorTests
        .currentDirectory
        .appending(path: "ExpectedOutput", directoryHint: .isDirectory)

    @Test
    func testGeneratesCodeForValidSchemaAndDocument() async throws {
        try await Codegen(
            .configuration(
                input: .input(
                    schemaSource: .SDLSchemaFile(
                        starwarsExampleDirectory.appending(path: "schema.sdl", directoryHint: .notDirectory)
                    ),
                    documentDirectories: [starwarsExampleDirectory]
                ),
                output: .output(
                    schema: .schema(
                        directory: starwarsExampleDirectory.appending(path: "SchemaTypes", directoryHint: .isDirectory)
                    ),
                    api: .api(
                        directory: starwarsExampleDirectory.appending(path: "API", directoryHint: .isDirectory),
                        HTTPSupport: .httpSupport(enableGETQueries: true)
                    )
                )
            )
        ).run()
        try OutputFile.allCases.forEach(verifyOutputFile)
    }

    private func verifyOutputFile(_ outputFile: OutputFile) throws {
        let expectedFileURL = expectedOutputDirectory.appending(
            path: outputFile.relativePath,
            directoryHint: .notDirectory
        )
        #expect(FileManager.default.fileExists(atPath: expectedFileURL.path(percentEncoded: false)))
        let outputFileURL = starwarsExampleDirectory.appending(
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
