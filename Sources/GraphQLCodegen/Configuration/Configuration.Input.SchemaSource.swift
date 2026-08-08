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
        ///   - includeDeprecated: Pass `true` if the GraphQL schema should include deprecated fields, arguments,
        ///   input fields, directive arguments, and enum values. Deprecated generated declarations are annotated with a Swift
        ///   warning where supported. Pass `false` to exclude deprecated schema members. Codegen will fail if an operation
        ///   references an excluded member.
        case introspectionEndpoint(
            url: URL,
            headers: [String: String] = [:],
            includeDeprecated: Bool = true
        )

        /// Instructs codegen to load your GraphQL schema from a .json file on the local filesystem.
        /// The JSON must match the object returned in the `data` field by the introspection query bundled with
        /// this version of the codegen and conform to the September 2025 GraphQL specification.
        case JSONSchemaFile(URL)

        /// Instructs codegen to load your GraphQL schema from a  .graphqls file on the local filesystem.
        /// The file should be formatted in valid Server Definition Langauge (SDL)
        case SDLSchemaFile(
            URL,
            includeDeprecated: Bool = true
        )
    }
}
