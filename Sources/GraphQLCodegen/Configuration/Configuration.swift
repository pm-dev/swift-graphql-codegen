import Foundation

/// A `Configuration` controls the behavior of `Codegen.run`. Recommended
/// defaults are provided where applicable, however the options here may be adjusted to
/// your specific needs and provides flexibility over the Swift code generated.
/// Please open an issue on the Github repo if you'd like to add a new configuration option.
public struct Configuration: Sendable {
    /// Call this function to create a new `Configuration` instance.
    ///
    /// - Parameters:
    ///   - input: Options controlling how to ingest the GraphQL schema and GraphQL operations.
    ///   - validation: Pass `true` (recommended) if you'd like to validate your GraphQL operations against your GraphQL schema.
    ///   Invalid operations are likely to cause errors during codegen, however if you're already sure all operations are valid,
    ///   you can skip this step by passing `false`.
    ///   - output: Options controlling the code that is output by this codegen.
    /// - Returns: A `Configuration` to be passed to `Codegen.run`
    public static func configuration(
        input: Input,
        validation: Bool = true,
        output: Output
    ) throws -> Configuration {
        try Configuration(
            input: input,
            validation: validation,
            output: output
        ).checkConfiguration()
    }

    public var input: Input
    public var validation: Bool
    public var output: Output

    private func checkConfiguration() throws -> Self {
        switch output.documents.operations.persistedOperations {
        case .registered(let manifestJSONFileOutput):
            try verifyLocalURL(
                manifestJSONFileOutput,
                expectedExtension: ["json"],
                parameter: "manifestJSONFileOutput",
                configuration: "persisted operations"
            )
        case .automatic, .none: break
        }
        switch input.schemaSource {
        case .JSONSchemaFile(let url):
            try verifyLocalURL(
                url,
                expectedExtension: ["json"],
                parameter: "JSONSchemaFile",
                configuration: "schema source"
            )
        case .SDLSchemaFile(let url, _, _):
            try verifyLocalURL(
                url,
                expectedExtension: ["graphqls", "sdl"],
                parameter: "SDLSchemaFile",
                configuration: "schema source"
            )
        case .introspectionEndpoint: break
        }
        return self
    }

    private func verifyLocalURL(
        _ url: URL,
        expectedExtension possibleExtensions: [String],
        parameter: String,
        configuration: String
    ) throws {
        guard url.isFileURL else {
            throw Codegen.Error(description: """
            The "\(parameter)" URL used in the \(configuration) configuration must be a local file.
            \(url)
            """)
        }
        let `extension` = url.pathExtension.lowercased()
        for possibleExtension in possibleExtensions where possibleExtension == `extension` {
            return
        }
        throw Codegen.Error(description: """
        The "\(parameter)" URL used in the \(configuration) configuration have an extenion in: \(possibleExtensions) file.
        \(url)
        """)
    }
}
