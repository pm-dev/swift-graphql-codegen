import Foundation

extension Configuration.Output {
    /// Options controlling generated schema types.
    /// A GraphQL schema defines scalars, enums and input objects which can be used by your operations.
    /// Codegen assumes exclusive ownership of the schema output directories selected by this configuration
    /// and may remove their existing contents before writing the current generated output.
    public struct Schema: Sendable {
        /// Call this function to create a new `Schema` instance.
        ///
        /// - Parameters:
        ///   - directory: The root directory on the local file system for generated schema files. Codegen may
        ///   remove and recreate the configured scalar, enum, and input-object directories within this root.
        ///   If a schema category's `directoryName` is `nil`, Codegen treats this root itself as that category's
        ///   exclusively owned output directory. Do not store unrelated files in directories owned by Codegen.
        ///   - scalars: Options controlling the code generated to represent scalar types.
        ///   - enums: Options controlling the code generated to represent enum types
        ///   - inputObjects: Options controlling the code generated to represent input object types.
        ///   - accessLevel: The `AccessLevel` for the generated swift code representing schema types.
        /// - Returns: A new `Schema` instance to be passed to the `Output.output` factory function.
        public static func schema(
            directory: URL,
            scalars: Scalars = .scalars(),
            enums: Enums = .enums(),
            inputObjects: InputObjects = .inputObjects(),
            accessLevel: AccessLevel = .internal
        ) -> Schema {
            Schema(
                directory: directory,
                scalars: scalars,
                enums: enums,
                inputObjects: inputObjects,
                accessLevel: accessLevel
            )
        }

        public var directory: URL
        public var scalars: Scalars
        public var enums: Enums
        public var inputObjects: InputObjects
        public var accessLevel: AccessLevel
    }
}
