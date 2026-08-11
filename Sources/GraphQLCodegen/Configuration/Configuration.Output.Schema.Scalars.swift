extension Configuration.Output.Schema {
    /// Options controlling the code generated to represent scalar types.
    ///
    /// Scalar files are regenerated on every run. Configure custom Swift types with `scalarMapping`;
    /// scalars without a mapping are generated as `String` typealiases.
    public struct Scalars: Sendable {
        /// The Swift type and optional module used to represent a GraphQL scalar.
        public struct Scalar: Sendable {
            /// A module imported by a generated scalar file.
            public struct Module: Sendable {
                public var name: String
                public var prefix: Bool

                /// Creates a module configuration for a generated scalar file.
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
            ///   - module: The module to import into this scalar's generated file.
            public static func scalar(typeName: String, module: Module? = nil) -> Scalar {
                Scalar(typeName: typeName, module: module)
            }
        }

        /// Call this function to create a new `Scalars` instance.
        ///
        /// - Parameters:
        ///   - directoryName: The name of the directory containing generated scalar files. This directory will be
        ///   placed inside the `Schema.directory` directory. If nil, scalar files will not be nested in their own directory.
        ///   - header: An optional string to include at the top of generated scalar files.
        ///   - importedModules: A list of modules to import into the generated scalar file.
        ///   Just include the module name, the "import" keyword will be added automatically.
        ///   - scalarMapping: Swift scalar mappings keyed by GraphQL scalar name. Unmapped scalars default to `String`.
        /// - Returns: A new `Scalars` instance to be passed to the `Schema.schema` factory function.
        public static func scalars(
            directoryName: String? = "Scalars",
            header: String? = "// @generated",
            importedModules: [String] = [],
            scalarMapping: [String: Scalar] = [:]
        ) -> Scalars {
            Scalars(
                directoryName: directoryName,
                header: header,
                importedModules: importedModules,
                scalarMapping: scalarMapping
            )
        }

        public var directoryName: String?
        public var header: String?
        public var importedModules: [String]
        public var scalarMapping: [String: Scalar]
    }
}
