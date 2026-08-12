extension Configuration {
    /// Options controlling the code that is output by this codegen.
    public struct Output: Sendable {
        /// Call this function to create a new `Output` instance.
        ///
        /// - Parameters:
        ///   - indentation:
        ///   - schema: Options controlling generated schema types. A GraphQL schema defines
        ///   scalars, enums and input objects which can be used by your operations.
        ///   Only schema types that are used by your operations will be generated.
        ///   - documents: Options controlling generated code for your GraphQL operations and fragments.
        ///   - support: Options controlling the code shared by your operations. This "infrastructure" code
        ///   includes types for accurately modeling server responses to operations (including errors) enums and nullable fields.
        /// - Returns: A new `Output` instance to be passed to the `Configuration.configuration` factory function.
        public static func output(
            indentation: Indentation = .spaces(4),
            schema: Schema,
            documents: Documents = .documents(),
            support: Support
        ) -> Output {
            Output(
                indentation: indentation,
                schema: schema,
                documents: documents,
                support: support
            )
        }

        public var indentation: Indentation
        public var schema: Schema
        public var documents: Documents
        public var support: Support
    }
}
