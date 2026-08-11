import Foundation

extension Configuration.Output {
    /// Options controlling the code shared by your operations.
    /// This "infrastructure" code includes types for accurately modeling server responses to
    /// operations (including errors) enums and nullable fields.
    ///
    /// Codegen writes all generated support types to `Support.swift` inside the configured directory.
    public struct Support: Sendable {
        /// Call this function to create a new `Support` instance.
        ///
        /// - Parameters:
        ///   - directory: The directory containing the generated `Support.swift` file.
        ///   - header: An optional string to include at the top of `Support.swift`.
        ///   - accessLevel: The `AccessLevel` for the generated support code.
        ///   - HTTPSupport: Options controlling support code generated for HTTP requests to GraphQL servers.
        ///   Passing `nil` excludes HTTP support from `Support.swift`.
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
