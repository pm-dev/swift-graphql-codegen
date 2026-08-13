extension Configuration.Output.Schema.Scalars.Scalar {
    /// A module imported by the generated `Schema.swift` file.
    public struct Module: Sendable {
        /// Creates a module configuration for a generated scalar declaration.
        ///
        /// - Parameters:
        ///   - name: The name of the module to import.
        ///   - prefix: Whether the generated typealias prefixes the type name with the module name.
        public static func module(name: String, prefix: Bool = false) -> Module {
            Module(name: name, prefix: prefix)
        }

        public var name: String
        public var prefix: Bool
    }
}
