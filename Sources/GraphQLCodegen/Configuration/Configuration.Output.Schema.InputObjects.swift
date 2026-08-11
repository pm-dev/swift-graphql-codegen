extension Configuration.Output.Schema {
    /// Options controlling the code generated to represent input object types.
    public struct InputObjects: Sendable {
        /// Call this function to create a new `InputObjects` instance.
        ///
        /// - Parameters:
        ///   - immutable: Pass `true` to make input objects immutable, meaning `let` will be used
        ///   for all properties. Pass `false` to make input objects mutable, meaning `var` will be used
        ///   for all properties.
        ///   - conformances: A list of protocols each generated input object will conform to.
        /// - Returns: A new `InputObjects` instance to be passed to the `Schema.schema` factory function.
        public static func inputObjects(
            immutable: Bool = true,
            conformances: [String] = ["Encodable", "Hashable", "Sendable"]
        ) -> InputObjects {
            InputObjects(
                immutable: immutable,
                conformances: conformances
            )
        }

        public var immutable: Bool
        public var conformances: [String]
    }
}
