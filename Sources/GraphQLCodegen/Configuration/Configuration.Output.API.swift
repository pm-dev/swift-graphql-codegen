import Foundation

extension Configuration.Output {
    /// Options controlling the code shared by your operations.
    /// This "infrastructure" code  includes types for accurately modeling server responses to
    /// operations (including errors) enums and nullable fields.
    public struct API: Sendable {
        /// Call this function to create a new `API` instance.
        ///
        /// - Parameters:
        ///   - directory: A `URL` to a location on the local file-system to write API files.
        ///   - header: An optional string to include at the top of generated document files.
        ///   - accessLevel: The `AccessLevel` for the generated API code.
        ///   - HTTPSupport: Options controlling API files that generated to support HTTP requests to GraphQL servers.
        ///   Passing `nil` will cause codegen to not generate these files.
        /// - Returns: A new `API` instance to be passed to the `Output.output` factory function.
        public static func api(
            directory: URL,
            header: String? = "// @generated",
            accessLevel: AccessLevel = .internal,
            HTTPSupport: HTTPSupport? = .httpSupport()
        ) -> API {
            API(
                directory: directory,
                header: header,
                accessLevel: accessLevel,
                HTTPSupport: HTTPSupport
            )
        }

        public var directory: URL
        public var header: String?
        public var accessLevel: AccessLevel
        public var HTTPSupport: HTTPSupport?
    }
}
