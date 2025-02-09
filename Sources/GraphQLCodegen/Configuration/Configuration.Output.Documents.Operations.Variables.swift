extension Configuration.Output.Documents.Operations {
    /// Options controlling generated code for an operation's "Variables" struct.
    public struct Variables: Sendable {
        /// Call this function to create a new `Variables` instance.
        ///
        /// - Parameters:
        ///   - immutable: Pass `true` to make input objects immutable, meaning `let` will be used
        ///   for all properties. Pass `false` to make input objects mutable, meaning `var` will be used
        ///   for all properties.
        ///   - conformances: A list of protocols each generated `Variables` struct will conform to.
        /// - Returns: A new `Variables` instance to be passed to the `Operations.operations` factory function.
        public static func variables(
            immutable: Bool = true,
            conformances: [String] = ["Encodable", "Sendable"]
        ) -> Variables {
            Variables(
                immutable: immutable,
                conformances: conformances
            )
        }

        public var immutable: Bool
        public var conformances: [String]
    }
}
