import Foundation

extension Configuration.Output {
    /// Options controlling the code shared by your operations.
    /// This "infrastructure" code  includes types for accurately modeling server responses to
    /// operations (including errors) enums and nullable fields.
    ///
    /// Codegen reserves the `HTTPSupport` subdirectory within the configured support directory. If HTTP support
    /// is disabled, Codegen may remove that subdirectory and all of its contents.
    public struct Support: Sendable {
        /// Call this function to create a new `Support` instance.
        ///
        /// - Parameters:
        ///   - directory: A `URL` to a location on the local file system to write support files. Codegen reserves
        ///   the `HTTPSupport` subdirectory at this location and may remove all of its contents when HTTP support
        ///   is disabled. Do not store unrelated or independently maintained files in that subdirectory.
        ///   - header: An optional string to include at the top of generated document files.
        ///   - accessLevel: The `AccessLevel` for the generated support code.
        ///   - HTTPSupport: Options controlling files generated for HTTP requests to GraphQL servers.
        ///   Passing `nil` prevents Codegen from generating these files and may remove the entire `HTTPSupport`
        ///   subdirectory from the configured support directory.
        /// - Returns: A new `Support` instance to be passed to the `Output.output` factory function.
        public static func support(
            directory: URL,
            header: String? = "// @generated",
            accessLevel: AccessLevel = .internal,
            HTTPSupport: HTTPSupport? = .httpSupport()
        ) -> Support {
            Support(
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
