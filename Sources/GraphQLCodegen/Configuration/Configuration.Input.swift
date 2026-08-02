import Foundation

extension Configuration {
    /// Options controlling how to ingest the GraphQL schema and GraphQL operations.
    public struct Input: Sendable {
        /// Call this function to create a new `Input` instance.
        ///
        /// - Parameters:
        ///   - schemaSource: The method controlling how to injest the GraphQL schema used in codegen.
        ///   - documentDirectories: A list of URLs to directories on the local file-system. Codegen will
        ///   recursively search these directories for GraphQL documents (files using a .graphql extension)
        /// - Returns: A new `Input` instance to be passed to the `Configuration.configuration` factory function.
        public static func input(
            schemaSource: SchemaSource,
            documentDirectories: [URL]
        ) -> Input {
            Input(
                schemaSource: schemaSource,
                documentDirectories: documentDirectories
            )
        }

        public var schemaSource: SchemaSource
        public var documentDirectories: [URL]
    }
}
