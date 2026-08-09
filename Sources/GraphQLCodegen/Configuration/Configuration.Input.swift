import Foundation

extension Configuration {
    /// Options controlling how to ingest the GraphQL schema and GraphQL operations.
    public struct Input: Sendable {
        /// Controls whether deprecated GraphQL schema members remain available to generated code.
        public enum DeprecationPolicy: Sendable {
            /// Include deprecated schema members. Generated declarations are annotated with a Swift warning where supported,
            /// and code generation warns when an operation uses a deprecated argument.
            case include

            /// Exclude deprecated schema members and fail code generation when an operation uses one.
            case exclude
        }

        /// Call this function to create a new `Input` instance.
        ///
        /// - Parameters:
        ///   - schemaSource: The method controlling how to injest the GraphQL schema used in codegen.
        ///   - documentDirectories: A list of URLs to directories on the local file-system. Codegen will
        ///   recursively search these directories for GraphQL documents (files using a .graphql extension)
        ///   - deprecationPolicy: Controls whether deprecated schema members remain available to generated code.
        /// - Returns: A new `Input` instance to be passed to the `Configuration.configuration` factory function.
        public static func input(
            schemaSource: SchemaSource,
            documentDirectories: [URL],
            deprecationPolicy: DeprecationPolicy = .include
        ) -> Input {
            Input(
                schemaSource: schemaSource,
                documentDirectories: documentDirectories,
                deprecationPolicy: deprecationPolicy
            )
        }

        public var schemaSource: SchemaSource
        public var documentDirectories: [URL]
        public var deprecationPolicy: DeprecationPolicy
    }
}
