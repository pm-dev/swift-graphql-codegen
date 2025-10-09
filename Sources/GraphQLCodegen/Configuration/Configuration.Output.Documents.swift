import Foundation

extension Configuration.Output {
    public enum DocumentOutputLocation: Sendable {
        /// Places generated swift documents in the same
        /// directory as its definition
        case definition
        /// Places generated swift documents in an explicity directory
        case directory(URL)
    }
    
    /// Options controlling generated code for your GraphQL documents. Each `.graphql` document
    /// will have a corresponding `.graphql.swift` file generated. Document files may contain any
    /// number of operation definitions and/or fragment definitions.
    public struct Documents: Sendable {
        /// Call this function to create a new `Documents` instance.
        ///
        /// - Parameters:
        ///   - directory: Where the generated fragment files will be located
        ///   - header: An optional string to include at the top of generated document files.
        ///   - importedModules: A list of modules to import into generated document files.
        ///   Just include the module name, the "import" keyword will be added automatically.
        ///   - operations: Options controlling generated code for operation definitions (which exist inside documents).
        ///   - fragments: Options controlling generated code for fragment definitions (which exist inside documents).
        ///   - accessLevel: The `AccessLevel` for the generated swift code representing operation and fragment types.
        ///   - memberwiseInitializer: Whether to create an explicit memberwise initializer.
        /// - Returns: A new `Documents` instance to be passed to the `Output.output` factory function.
        public static func documents(
            directory: DocumentOutputLocation = .definition,
            header: String? = "// @generated",
            importedModules: [String] = [],
            operations: Operations = .operations(),
            fragments: Fragments = .fragments(),
            accessLevel: AccessLevel = .internal,
            memberwiseInitializer: Bool = false
        ) -> Documents {
            Documents(
                directory: directory,
                header: header,
                importedModules: importedModules,
                operations: operations,
                fragments: fragments,
                accessLevel: accessLevel,
                memberwiseInitializer: memberwiseInitializer
            )
        }

        public var directory: DocumentOutputLocation
        public var header: String?
        public var importedModules: [String]
        public var operations: Operations
        public var fragments: Fragments
        public var accessLevel: AccessLevel
        public var memberwiseInitializer: Bool
    }
}
