extension Configuration.Output.Schema {
    /// Options controlling the code generated to represent scalar types.
    ///
    /// Scalar declarations are regenerated on every run. Configure custom Swift types with `scalarMapping`;
    /// scalars without a mapping are generated as `String` typealiases.
    public struct Scalars: Sendable {
        /// The Swift type and optional module used to represent a GraphQL scalar.
        public struct Scalar: Sendable {
            /// A module imported by the generated `Schema.swift` file.
            public struct Module: Sendable {
                public var name: String
                public var prefix: Bool

                /// Creates a module configuration for a generated scalar declaration.
                ///
                /// - Parameters:
                ///   - name: The name of the module to import.
                ///   - prefix: Whether the generated typealias prefixes the type name with the module name.
                public static func module(name: String, prefix: Bool = false) -> Module {
                    Module(name: name, prefix: prefix)
                }
            }

            public var typeName: String
            public var module: Module?

            /// Creates a Swift type mapping for a GraphQL scalar.
            ///
            /// - Parameters:
            ///   - typeName: The Swift type used by this scalar's generated typealias.
            ///   - module: The module to import into the generated `Schema.swift` file.
            public static func scalar(typeName: String, module: Module? = nil) -> Scalar {
                Scalar(typeName: typeName, module: module)
            }
        }

        /// Call this function to create a new `Scalars` instance.
        ///
        /// - Parameters:
        ///   - scalarMapping: Swift scalar mappings keyed by GraphQL scalar name. Unmapped scalars default to `String`.
        /// - Returns: A new `Scalars` instance to be passed to the `Schema.schema` factory function.
        public static func scalars(
            scalarMapping: [String: Scalar] = [:]
        ) -> Scalars {
            Scalars(
                scalarMapping: scalarMapping
            )
        }

        public var scalarMapping: [String: Scalar]
    }
}
