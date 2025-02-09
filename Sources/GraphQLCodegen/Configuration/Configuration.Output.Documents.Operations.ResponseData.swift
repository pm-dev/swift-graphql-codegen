extension Configuration.Output.Documents.Operations {
    /// Options controlling generated code for the response "Data" struct.
    public struct ResponseData: Sendable {
        /// Call this function to create a new `ResponseData` instance.
        ///
        /// - Parameters:
        ///   - immutable: Pass `true` to make data structs immutable, meaning `let` will be used
        ///   for properties. Pass `false` to make data structs mutable, meaning `var` will be used
        ///   for properties.
        ///   - conformances: A list of protocols each generated `Data` struct will conform to.
        /// - Returns: A new `ResponseData` instance to be passed to the `Operations.operations` factory function.
        public static func responseData(
            immutable: Bool = true,
            conformances: [String] = ["Decodable", "Sendable"]
        ) -> ResponseData {
            ResponseData(
                immutable: immutable,
                conformances: conformances
            )
        }

        public var immutable: Bool
        public var conformances: [String]
    }
}
