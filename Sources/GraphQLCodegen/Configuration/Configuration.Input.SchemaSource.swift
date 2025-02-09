import Foundation

extension Configuration.Input {
    /// The method controlling how to injest the GraphQL schema used in codegen.
    public enum SchemaSource: Sendable {
        /// Instructs codegen to obtain your GraphQL schema by introspecting a GraphQL endpoint.
        ///
        /// - Parameters:
        ///   - url: The URL of the GraphQL endpoint. Make sure the GraphQL endpoint has introspection enabled.
        ///   Refer to the spec for more info on introspection.
        ///   - includeDeprecatedFields: Pass `true` if the GraphQL schema should include fields that have been
        ///   deprecated by the server. When deprecated fields are included, your GraphQL operations may query against these fields,
        ///   but they will be annotated with a Swift warning. Pass `false` to exclude deprecated fields. When deprecated fields are excluded
        ///   codegen will fail if your operations query against those fields.
        ///   - includeDeprecatedEnumValues: Pass `true` if the GraphQL schema should include enum values (cases) that have
        ///   been deprecated by the server. When deprecated enum values are included, the generated enum will include those cases,
        ///   but they will be annotated with a Swift warning. Pass `false` to excluded deprecated enum values. When deprecated enum
        ///   values are excluded, your code will not be able to reference those values.
        case introspectionEndpoint(
            url: URL,
            includeDeprecatedFields: Bool = true,
            includeDeprecatedEnumValues: Bool = true
        )

        /// Instructs codegen to load your GraphQL schema from a .json file on the local filesystem.
        /// The json format should match what would be included in the "data" field of an introspection query.
        case JSONSchemaFile(URL)

        /// Instructs codegen to load your GraphQL schema from a  .graphqls file on the local filesystem.
        /// The file should be formatted in valid Server Definition Langauge (SDL)
        case SDLSchemaFile(
            URL,
            includeDeprecatedFields: Bool = true,
            includeDeprecatedEnumValues: Bool = true
        )
    }
}
