import Foundation

extension Configuration.Input {
    /// The method controlling how to injest the GraphQL schema used in codegen.
    public enum SchemaSource: Sendable {
        /// Instructs codegen to obtain your GraphQL schema by introspecting a GraphQL endpoint.
        ///
        /// - Parameters:
        ///   - url: The URL of the GraphQL endpoint. The endpoint must enable and implement introspection from the
        ///   [September 2025 GraphQL specification](https://spec.graphql.org/September2025/#sec-Schema-Introspection).
        ///   Earlier introspection schemas are not supported.
        ///   - headers: Additional HTTP headers, such as authorization, to send to this endpoint.
        case introspectionEndpoint(
            url: URL,
            headers: [String: String] = [:]
        )

        /// Instructs codegen to load your GraphQL schema from a .json file on the local filesystem.
        /// The JSON must match the object returned in the `data` field by the introspection query bundled with
        /// this version of the codegen, include deprecated schema members, and conform to the September 2025 GraphQL
        /// specification. The selected deprecation policy is applied after loading the complete schema.
        case JSONSchemaFile(URL)

        /// Instructs codegen to load your GraphQL schema from a  .graphqls file on the local filesystem.
        /// The file should be formatted in valid Server Definition Langauge (SDL)
        case SDLSchemaFile(URL)
    }
}
