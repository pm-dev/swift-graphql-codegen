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
        ///   - minifyDocument: Pass `true` to remove descriptions and ignored characters from the generated
        ///   `document`, optimizing for a smaller transport payload. Pass `false` to preserve source formatting,
        ///   which makes the document easier to read while debugging and reduces merge conflicts when parallel
        ///   edits change different lines of the document.
        ///   - conformances: A list of protocols each generated operation will conform to.
        ///   - variables: Options controlling generated code for the variables struct.
        ///   - responseData: Options controlling generated code for the response "Data" struct.
        /// - Returns: A new `Operations` instance to be passed to the `Documents.documents` factory function.
        public static func operations(
            immutableExtensions: Bool = true,
            immutableVariables: Bool = true,
            minifyDocument: Bool = true,
            conformances: [String] = [],
            variables: Variables = .variables(),
            responseData: ResponseData = .responseData()
        ) -> Operations {
            Operations(
                immutableExtensions: immutableExtensions,
                immutableVariables: immutableVariables,
                minifyDocument: minifyDocument,
                conformances: conformances,
                variables: variables,
                responseData: responseData
            )
        }

        public var immutableExtensions: Bool
        public var immutableVariables: Bool
        public var minifyDocument: Bool
        public var conformances: [String]
        public var variables: Variables
        public var responseData: ResponseData
    }
}
