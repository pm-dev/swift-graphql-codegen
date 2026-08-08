extension Configuration.Output.Documents {
    /// Options controlling generated Swift structs for operation definitions contained in `.graphql` documents.
    public struct Operations: Sendable {
        /// Call this function to create a new `Operations` instance.
        ///
        /// - Parameters:
        ///   - immutableExtensions: Pass `true` to make the extensions property of generated operations
        ///   use `let`. Pass false to make the property a `var`.
        ///   - immutableVariables: Pass `true` to make the variables property of generated operations
        ///   use `let`. Pass false to make the property a `var`.
        ///   - conformances: A list of protocols each generated operation will conform to.
        ///   - variables: Options controlling generated code for the variables struct.
        ///   - persistedOperations: Controls whether operations support persisted operations. Pass nil to remove
        ///   support for persisted operations.
        ///   - responseData: Options controlling generated code for the response "Data" struct.
        /// - Returns: A new `Operations` instance to be passed to the `Documents.documents` factory function.
        public static func operations(
            immutableExtensions: Bool = true,
            immutableVariables: Bool = true,
            conformances: [String] = [],
            variables: Variables = .variables(),
            persistedOperations: PersistedOperations? = .automatic,
            responseData: ResponseData = .responseData()
        ) -> Operations {
            Operations(
                immutableExtensions: immutableExtensions,
                immutableVariables: immutableVariables,
                conformances: conformances,
                variables: variables,
                persistedOperations: persistedOperations,
                responseData: responseData
            )
        }

        public var immutableExtensions: Bool
        public var immutableVariables: Bool
        public var conformances: [String]
        public var variables: Variables
        public var persistedOperations: PersistedOperations?
        public var responseData: ResponseData
    }
}
