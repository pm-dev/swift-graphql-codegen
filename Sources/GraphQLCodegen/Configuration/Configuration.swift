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
    ) -> Configuration {
        Configuration(
            input: input,
            validation: validation,
            output: output
        )
    }

    /// Creates configuration that writes exactly three deterministic Swift source files.
    ///
    /// This output mode is suitable for SwiftPM build-tool plugins and is also available to
    /// code generation invoked directly by an application or executable.
    public static func configuration(
        input: Input,
        validation: Bool = true,
        output: Output.GeneratedFiles
    ) -> Configuration {
        Configuration(
            input: input,
            validation: validation,
            output: output.configurationOutput
        )
    }

    /// Creates configuration for code generation invoked by a SwiftPM build-tool plugin.
    ///
    /// Build-tool plugins run without network access, so this factory accepts only local schema files.
    ///
    /// - Parameters:
    ///   - input: Local schema and GraphQL document inputs.
    ///   - validation: Whether to validate GraphQL documents against the schema.
    ///   - output: Options controlling the three deterministic generated Swift files.
    /// - Returns: Configuration to pass to `Codegen.init(_:)`.
    public static func buildPluginConfiguration(
        input: BuildPluginInput,
        validation: Bool = true,
        output: Output.GeneratedFiles
    ) -> Configuration {
        .configuration(
            input: .input(
                schemaSource: .file(input.schemaFile),
                documentDirectories: input.documentDirectories,
                deprecationPolicy: input.deprecationPolicy
            ),
            validation: validation,
            output: output
        )
    }

    public var input: Input
    public var validation: Bool
    public var output: Output

    func validate() throws {
        if case .spaces(let count) = output.indentation, count < 0 {
            throw Codegen.Error(description: "The indentation space count must not be negative.")
        }
        if output.generatedFilesDirectory != nil,
           case .registered = output.api.HTTPSupport?.persistedOperations {
            throw Codegen.Error(description: """
            Generated-files output cannot create a registered persisted-operation manifest because it only supports its three declared Swift files.
            """)
        }
        switch output.api.HTTPSupport?.persistedOperations {
        case .registered(let manifestJSONFileOutput, _):
            try verifyLocalURL(
                manifestJSONFileOutput,
                expectedExtension: ["json"],
                parameter: "manifestJSONFileOutput",
                configuration: "persisted operations"
            )
        case .automatic, .none: break
        }
        switch input.schemaSource {
        case .file(.introspectionJSON(let url)):
            try verifyLocalURL(
                url,
                expectedExtension: ["json"],
                parameter: "introspectionJSON",
                configuration: "schema source"
            )
        case .file(.SDL(let url)):
            try verifyLocalURL(
                url,
                expectedExtension: ["graphql", "graphqls", "sdl"],
                parameter: "SDL",
                configuration: "schema source"
            )
        case .introspectionEndpoint: break
        }
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
