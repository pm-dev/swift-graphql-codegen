import Foundation
import GraphQLCodegen
import Testing

struct AnonymousOperationTypeNameTests {
    @Test(
        arguments: [
            (fileName: "current-user.graphql", typeName: "currentUserQuery"),
            (fileName: "current_user.graphql", typeName: "current_userQuery"),
            (fileName: "2-current-users.graphql", typeName: "_2CurrentUsersQuery"),
        ]
    )
    func derivesValidTypeName(fileName: String, typeName: String) async throws {
        let fixture = try makeFixture(documentFileName: fileName)
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        try await Codegen(configuration(for: fixture)).run()

        let generatedDocument = fixture.output
            .appending(path: "Operations", directoryHint: .isDirectory)
            .appending(path: fileName + ".swift", directoryHint: .notDirectory)
        let source = try String(contentsOf: generatedDocument, encoding: .utf8)
        #expect(source.contains("struct \(typeName):"))
    }

    @Test
    func rejectsFileNameWithoutSwiftIdentifierCharacters() async throws {
        let fixture = try makeFixture(documentFileName: "---.graphql")
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        do {
            try await Codegen(configuration(for: fixture)).run()
            Issue.record("Expected codegen to reject the filename")
        } catch {
            #expect(
                String(describing: error).contains(
                    "filename contains no Swift identifier characters"
                )
            )
        }
    }

    @Test
    func usesNearestConfiguredDocumentRootForOutputPath() async throws {
        let fileName = "current-user.graphql"
        let fixture = try makeFixture(documentFileName: fileName)
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        var configuration = configuration(for: fixture)
        configuration.input.documentDirectories = [
            fixture.operations.deletingLastPathComponent(),
            fixture.operations,
        ]

        try await Codegen(configuration).run()

        let outputDirectory = fixture.output.appending(path: "Operations", directoryHint: .isDirectory)
        #expect(
            FileManager.default.fileExists(
                atPath: outputDirectory.appending(path: fileName + ".swift").path(percentEncoded: false)
            )
        )
        #expect(
            !FileManager.default.fileExists(
                atPath: outputDirectory
                    .appending(path: "Operations/" + fileName + ".swift")
                    .path(percentEncoded: false)
            )
        )
    }

    @Test(arguments: [false, true])
    func validatesDuplicateDocumentFilenamesOnlyForSharedOutputDirectories(
        generateBesideDefinitions: Bool
    ) async throws {
        let filename = "Value.graphql"
        let fixture = try makeFixture(documentFileName: filename)
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let firstDocument = fixture.operations.appending(path: filename, directoryHint: .notDirectory)
        try Data("query FirstValue { currentUser }".utf8).write(to: firstDocument)
        let otherOperations = fixture.root.appending(path: "OtherOperations", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: otherOperations, withIntermediateDirectories: true)
        let secondDocument = otherOperations.appending(path: filename, directoryHint: .notDirectory)
        try Data("query SecondValue { currentUser }".utf8).write(to: secondDocument)

        var configuration = configuration(for: fixture)
        configuration.input.documentDirectories = [fixture.operations, otherOperations]
        if generateBesideDefinitions {
            configuration.output.documents.directory = .definition
            try await Codegen(configuration).run()

            #expect(FileManager.default.fileExists(atPath: firstDocument.appendingPathExtension("swift").path))
            #expect(FileManager.default.fileExists(atPath: secondDocument.appendingPathExtension("swift").path))
        } else {
            do {
                try await Codegen(configuration).run()
                Issue.record("Expected duplicate GraphQL document filenames to be rejected")
            } catch {
                let description = String(describing: error)
                #expect(description.contains("GraphQL document filenames must be unique"))
                #expect(description.contains(filename))
                #expect(description.contains(firstDocument.path))
                #expect(description.contains(secondDocument.path))
            }
        }
    }

    private func configuration(for fixture: AnonymousOperationFixture) -> Configuration {
        .configuration(
            input: .input(
                schemaSource: .SDLSchemaFile(fixture.schema),
                documentDirectories: [fixture.operations]
            ),
            output: .output(
                schema: .schema(
                    directory: fixture.output.appending(path: "Schema", directoryHint: .isDirectory)
                ),
                documents: .documents(
                    directory: .directory(
                        fixture.output.appending(path: "Operations", directoryHint: .isDirectory)
                    )
                ),
                support: .support(
                    directory: fixture.output.appending(path: "Support", directoryHint: .isDirectory)
                )
            )
        )
    }

    private func makeFixture(documentFileName: String) throws -> AnonymousOperationFixture {
        let root = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        let definitions = root.appending(path: "Definitions", directoryHint: .isDirectory)
        let operations = definitions.appending(path: "Operations", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: operations, withIntermediateDirectories: true)
        let schema = definitions.appending(path: "schema.sdl", directoryHint: .notDirectory)
        try Data("type Query { currentUser: String! }".utf8).write(to: schema)
        try Data("query { currentUser }".utf8).write(
            to: operations.appending(path: documentFileName, directoryHint: .notDirectory)
        )
        return AnonymousOperationFixture(
            root: root,
            schema: schema,
            operations: operations,
            output: root.appending(path: "Output", directoryHint: .isDirectory)
        )
    }
}

private struct AnonymousOperationFixture {
    let root: URL
    let schema: URL
    let operations: URL
    let output: URL
}
