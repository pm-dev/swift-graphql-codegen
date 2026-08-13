extension Configuration.Output.Schema.Scalars {
    /// The Swift type and optional module used to represent a GraphQL scalar.
    public struct Scalar: Sendable {
        /// Creates a Swift type mapping for a GraphQL scalar.
        ///
        /// - Parameters:
        ///   - typeName: The Swift type used by this scalar's generated typealias.
        ///   - module: The module to import into the generated `Schema.swift` file.
        public static func scalar(typeName: String, module: Module? = nil) -> Scalar {
            Scalar(typeName: typeName, module: module)
        }

        public var typeName: String
        public var module: Module?
    }
}
