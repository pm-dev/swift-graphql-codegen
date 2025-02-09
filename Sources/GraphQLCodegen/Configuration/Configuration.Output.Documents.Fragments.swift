extension Configuration.Output.Documents {
    /// Options controlling generated Swift structs for fragment definitions contained in `.graphql` documents.
    public struct Fragments: Sendable {
        /// Call this function to create a new `Fragments` instance.
        ///
        /// - Parameters:
        ///   - immutable: Pass `true` to make fragment structs immutable, meaning `let` will be used
        ///   for properties. Pass `false` to make fragment structs mutable, meaning `var` will be used
        ///   for properties.
        ///   - conformances: A list of protocols each generated fragment struct will conform to.
        /// - Returns: A new `Fragments` instance to be passed to the `Documents.documents` factory function.
        public static func fragments(
            immutable: Bool = false,
            conformances: [String] = ["Decodable", "Sendable", "Hashable"]
        ) -> Fragments {
            Fragments(
                immutable: immutable,
                conformances: conformances
            )
        }

        public var immutable: Bool
        public var conformances: [String]
    }
}
