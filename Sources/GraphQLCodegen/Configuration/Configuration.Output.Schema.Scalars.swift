extension Configuration.Output.Schema {
    /// Options controlling the code generated to represent scalar types.
    ///
    /// Codegen only creates a file for scalars if there's not already an existing file for the scalar.
    /// This differs from Enum and Input Object files which will always override existing code.
    /// This behavior allows you to customize scalar types. By default, scalars are simple String typealiases
    /// but you are free to change that and create full types for scalars, or use a typealias to an already existing
    /// type (i.e. `Foundation.URL` or `Foundation.UUID`)
    public struct Scalars: Sendable {
        /// Call this function to create a new `Scalars` instance.
        ///
        /// - Parameters:
        ///   - directoryName: The name of the directory containing generated scalar files. This directory will be
        ///   placed inside the `Schema.directory` directory. If nil, scalar files will not be nested in their own directory.
        ///   - header: An optional string to include at the top of generated scalar files.
        ///   - importedModules: A list of modules to import into the generated scalar file.
        ///   Just include the module name, the "import" keyword will be added automatically.
        /// - Returns: A new `Scalars` instance to be passed to the `Schema.schema` factory function.
        public static func scalars(
            directoryName: String? = "Scalars",
            header: String? = """
            // @generated
            // Any changes to this file will not be overwritten by future code generation execution.
            """,
            importedModules: [String] = []
        ) -> Scalars {
            Scalars(
                directoryName: directoryName,
                header: header,
                importedModules: importedModules
            )
        }

        public var directoryName: String?
        public var header: String?
        public var importedModules: [String]
    }
}
