import Foundation

extension Configuration.Output {
    /// Options controlling generated schema types.
    /// A GraphQL schema defines scalars, enums and input objects which can be used by your operations.
    public struct Schema: Sendable {
        /// Call this function to create a new `Schema` instance.
        ///
        /// - Parameters:
        ///   - directory: A directory URL on the local file system where generated schema files will
        ///   be written to.
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
