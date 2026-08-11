import Foundation

extension Configuration.Output {
    /// Options controlling generated schema types.
    /// A GraphQL schema defines scalars, enums and input objects which can be used by your operations.
    /// Codegen writes all generated schema types to `Schema.swift` inside the configured directory.
    public struct Schema: Sendable {
        /// Call this function to create a new `Schema` instance.
        ///
        /// - Parameters:
        ///   - directory: The directory containing the generated `Schema.swift` file.
        ///   - header: An optional string to include at the top of `Schema.swift`.
        ///   - importedModules: Modules to import into `Schema.swift`. The `import` keyword is added automatically.
        ///   - scalars: Options controlling the code generated to represent scalar types.
        ///   - enums: Options controlling the code generated to represent enum types
        ///   - inputObjects: Options controlling the code generated to represent input object types.
        ///   - accessLevel: The `AccessLevel` for the generated swift code representing schema types.
        /// - Returns: A new `Schema` instance to be passed to the `Output.output` factory function.
        public static func schema(
            directory: URL,
            header: String? = "// @generated",
            importedModules: [String] = [],
            scalars: Scalars = .scalars(),
            enums: Enums = .enums(),
            inputObjects: InputObjects = .inputObjects(),
            accessLevel: AccessLevel = .internal
        ) -> Schema {
            Schema(
                directory: directory,
                header: header,
                importedModules: importedModules,
                scalars: scalars,
                enums: enums,
                inputObjects: inputObjects,
                accessLevel: accessLevel
            )
        }

        public var directory: URL
        public var header: String?
        public var importedModules: [String]
        public var scalars: Scalars
        public var enums: Enums
        public var inputObjects: InputObjects
        public var accessLevel: AccessLevel
    }
}
