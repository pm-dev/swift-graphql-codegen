import Foundation

extension Configuration.Input {
    /// Controls whether deprecated GraphQL schema members remain available to generated code.
    public enum DeprecationPolicy: Sendable {
        /// Include deprecated schema members. Generated declarations are annotated with a Swift warning where supported,
        /// and code generation warns when an operation uses a deprecated field argument.
        case include

        /// Exclude deprecated schema members and fail code generation when an operation uses one.
        case exclude
    }

    /// The method controlling how to injest the GraphQL schema used in codegen.
    public enum SchemaSource: Sendable {
        /// Instructs codegen to obtain your GraphQL schema by introspecting a GraphQL endpoint.
        ///
        /// - Parameters:
        ///   - url: The URL of the GraphQL endpoint. The endpoint must enable and implement introspection from the
        ///   [September 2025 GraphQL specification](https://spec.graphql.org/September2025/#sec-Schema-Introspection).
        ///   Earlier introspection schemas are not supported.
        ///   - headers: Additional HTTP headers, such as authorization, to send to this endpoint.
        ///   - deprecationPolicy: Controls whether deprecated schema members remain available to generated code.
        case introspectionEndpoint(
            url: URL,
            headers: [String: String] = [:],
            deprecationPolicy: DeprecationPolicy = .include
        )

        /// Instructs codegen to load your GraphQL schema from a .json file on the local filesystem.
        /// The JSON must match the object returned in the `data` field by the introspection query bundled with
        /// this version of the codegen, include deprecated schema members, and conform to the September 2025 GraphQL
        /// specification. The selected deprecation policy is applied after loading the complete schema.
        /// - Parameters:
        ///   - url: The local introspection JSON file.
        ///   - deprecationPolicy: Controls whether deprecated schema members remain available to generated code.
        case JSONSchemaFile(
            URL,
            deprecationPolicy: DeprecationPolicy = .include
        )

        /// Instructs codegen to load your GraphQL schema from a  .graphqls file on the local filesystem.
        /// The file should be formatted in valid Server Definition Langauge (SDL)
        ///
        /// - Parameters:
        ///   - url: The local SDL schema file.
        ///   - deprecationPolicy: Controls whether deprecated schema members remain available to generated code.
        case SDLSchemaFile(
            URL,
            deprecationPolicy: DeprecationPolicy = .include
        )
    }
}

extension Configuration.Input.SchemaSource {
    var deprecationPolicy: Configuration.Input.DeprecationPolicy {
        switch self {
        case .introspectionEndpoint(_, _, let deprecationPolicy),
             .JSONSchemaFile(_, let deprecationPolicy),
             .SDLSchemaFile(_, let deprecationPolicy):
            deprecationPolicy
        }
    }
}
