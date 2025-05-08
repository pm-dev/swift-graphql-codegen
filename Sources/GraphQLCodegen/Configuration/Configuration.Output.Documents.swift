extension Configuration.Output {
    /// Options controlling generated code for your GraphQL documents. Each `.graphql` document
    /// will have a corresponding `.graphql.swift` file generated. Document files may contain any
    /// number of operation definitions and/or fragment definitions.
    public struct Documents: Sendable {
        /// Call this function to create a new `Documents` instance.
        ///
        /// - Parameters:
        ///   - header: An optional string to include at the top of generated document files.
        ///   - importedModules: A list of modules to import into generated document files.
        ///   Just include the module name, the "import" keyword will be added automatically.
        ///   - operations: Options controlling generated code for operation definitions (which exist inside documents).
        ///   - fragments: Options controlling generated code for fragment definitions (which exist inside documents).
        ///   - accessLevel: The `AccessLevel` for the generated swift code representing operation and fragment types.
        /// - Returns: A new `Documents` instance to be passed to the `Output.output` factory function.
        public static func documents(
            header: String? = "// @generated",
            importedModules: [String] = [],
            operations: Operations = .operations(),
            fragments: Fragments = .fragments(),
            accessLevel: AccessLevel = .internal
        ) -> Documents {
            Documents(
                header: header,
                importedModules: importedModules,
                operations: operations,
                fragments: fragments,
                accessLevel: accessLevel
            )
        }
        public var header: String?
        public var importedModules: [String]
        public var operations: Operations
        public var fragments: Fragments
        public var accessLevel: AccessLevel
    }
}
