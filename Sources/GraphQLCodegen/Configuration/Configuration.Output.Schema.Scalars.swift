extension Configuration.Output.Schema {
    /// Options controlling the code generated to represent scalar types.
    ///
    /// Scalar declarations are regenerated on every run. Configure custom Swift types with `scalarMapping`;
    /// scalars without a mapping are generated as `String` typealiases.
    public struct Scalars: Sendable {
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
