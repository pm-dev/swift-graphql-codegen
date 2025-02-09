extension Configuration.Output.Schema {
    /// Options controlling the code generated to represent input object types.
    public struct InputObjects: Sendable {
        /// Call this function to create a new `InputObjects` instance.
        ///
        /// - Parameters:
        ///   - directoryName: The name of the directory containing generated input object files. This directory will be
        ///   placed inside the `Schema.directory` directory. If nil, input object files will not be nested in their own directory.
        ///   - header: An optional string to include at the top of generated input object files.
        ///   - importedModules: A list of modules to import into generated input object files.
        ///   Just include the module name, the "import" keyword will be added automatically.
        ///   - immutable: Pass `true` to make input objects immutable, meaning `let` will be used
        ///   for all properties. Pass `false` to make input objects mutable, meaning `var` will be used
        ///   for all properties.
        ///   - conformances: A list of protocols each generated input object will conform to.
        /// - Returns: A new `InputObjects` instance to be passed to the `Schema.schema` factory function.
        public static func inputObjects(
            directoryName: String? = "InputObjects",
            header: String? = "// @generated",
            importedModules: [String] = [],
            immutable: Bool = true,
            conformances: [String] = ["Encodable", "Hashable", "Sendable"]
        ) -> InputObjects {
            InputObjects(
                directoryName: directoryName,
                header: header,
                importedModules: importedModules,
                immutable: immutable,
                conformances: conformances
            )
        }

        public var directoryName: String?
        public var header: String?
        public var importedModules: [String]
        public var immutable: Bool
        public var conformances: [String]
    }
}
