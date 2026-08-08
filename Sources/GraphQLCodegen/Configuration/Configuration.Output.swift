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
        ///   - api: Options controlling the code shared by your operations. This "infrastructure" code
        ///   includes types for accurately modeling server responses to operations (including errors) enums and nullable fields.
        /// - Returns: A new `Output` instance to be passed to the `Configuration.configuration` factory function.
        public static func output(
            indentation: Indentation = .spaces(4),
            schema: Schema,
            documents: Documents = .documents(),
            api: API
        ) -> Output {
            Output(
                indentation: indentation,
                schema: schema,
                documents: documents,
                api: api
            )
        }

        public var indentation: Indentation
        public var schema: Schema
        public var documents: Documents
        public var api: API
    }
}

extension Configuration.Output {
    /// Controls the access level of a Swift type such as a struct or a property
    public enum AccessLevel: Sendable {
        /// Applies an internal access level to a Swift type. Since internal is the default
        /// access level in Swift, an access level keyword will be ommitted from output source code
        case `internal`

        /// Applies a public access level to a Swift type. These locations will be visible outside the
        /// module in which the source code lives.
        case `public`
    }

    /// Controls whether indentation in generation files uses spaces or a tab
    public enum Indentation: Sendable {
        /// Indentation will use the \t character
        case tab

        /// Indentation will use the given number of spaces
        case spaces(Int)

        var string: String {
            switch self {
            case .tab: "\t"
            case .spaces(let int): String(repeating: " ", count: int)
            }
        }
    }
}
