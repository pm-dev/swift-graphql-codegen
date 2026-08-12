extension Configuration.Output.Schema {
    /// Options controlling the code generated to represent enum types
    public struct Enums: Sendable {
        /// Call this function to create a new `Enums` instance.
        ///
        /// - Parameters:
        ///   - conformances: A list of protocols each generated enum will conform to.
        ///   - caseConversion: Optionally, the letter casing that enum cases should be converted to.
        /// - Returns: A new `Enums` instance to be passed to the `Schema.schema` factory function.
        public static func enums(
            conformances: [String] = ["Encodable", "Sendable"],
            caseConversion: CaseConversion? = nil
        ) -> Enums {
            Enums(
                conformances: conformances,
                caseConversion: caseConversion
            )
        }

        public var conformances: [String]
        public var caseConversion: CaseConversion?
    }
}
