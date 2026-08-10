import Foundation

extension Configuration {
    /// Local inputs available to code generation running in a SwiftPM build-tool plugin.
    public struct BuildPluginInput: Sendable {
        /// Creates local inputs for code generation invoked by a SwiftPM build-tool plugin.
        ///
        /// - Parameters:
        ///   - schemaFile: A checked-in SDL or introspection JSON schema file.
        ///   - documentDirectories: Directories recursively searched for `.graphql` documents.
        ///   - deprecationPolicy: Whether deprecated schema members remain available to generated code.
        /// - Returns: Input to pass to `Configuration.buildPluginConfiguration`.
        public static func input(
            schemaFile: Configuration.Input.SchemaSource.SchemaFile,
            documentDirectories: [URL],
            deprecationPolicy: Configuration.Input.DeprecationPolicy = .include
        ) -> BuildPluginInput {
            BuildPluginInput(
                schemaFile: schemaFile,
                documentDirectories: documentDirectories,
                deprecationPolicy: deprecationPolicy
            )
        }

        public var schemaFile: Configuration.Input.SchemaSource.SchemaFile
        public var documentDirectories: [URL]
        public var deprecationPolicy: Configuration.Input.DeprecationPolicy
    }
}
