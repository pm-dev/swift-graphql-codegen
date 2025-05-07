extension Configuration.Output.Schema {
    /// Options controlling the code generated to represent enum types
    public struct Enums: Sendable {
        /// Call this function to create a new `Enums` instance.
        ///
        /// - Parameters:
        ///   - directoryName: The name of the directory containing generated enum files. This directory will be
        ///   placed inside the `Schema.directory` directory. If nil, enum files will not be nested in their own directory.
        ///   - header: An optional string to include at the top of generated enum files.
        ///   - importedModules: A list of modules to import into generated enum files.
        ///   Just include the module name, the "import" keyword will be added automatically.
        ///   - conformances: A list of protocols each generated enum will conform to.
        ///   - caseConversion: Optionally, the letter casing that enum cases should be converted to.
        /// - Returns: A new `Enums` instance to be passed to the `Schema.schema` factory function.
        public static func enums(
            directoryName: String? = "Enums",
            header: String? = "// @generated",
            importedModules: [String] = [],
            conformances: [String] = ["Encodable", "Sendable"],
            caseConversion: CaseConversion? = nil
        ) -> Enums {
            Enums(
                directoryName: directoryName,
                header: header,
                importedModules: importedModules,
                conformances: conformances,
                caseConversion: caseConversion
            )
        }

        public var directoryName: String?
        public var header: String?
        public var importedModules: [String]
        public var conformances: [String]
        public var caseConversion: CaseConversion?
    }
}

extension Configuration.Output.Schema.Enums {
    /// Type of letter casing to convert enum cases to
    /// For example, an enum in a GQL schema may define the option `NORTH_WEST`
    /// If a CaseConversion is used, it must specify `from: .macro` and `to` may be any case.
    /// If `lowerCamel` is used, this codegen would create `case northWest`
    public struct CaseConversion: Sendable {
        public enum Case: Sendable {
            case lowerCamel // thisIsCamelCase
            case macro // THIS_IS_MACRO_CASE
        }

        public var from: Case
        public var to: Case
        public static func conversion(from: Case, to: Case) -> CaseConversion {
            CaseConversion(
                from: from,
                to: to
            )
        }
    }
}
