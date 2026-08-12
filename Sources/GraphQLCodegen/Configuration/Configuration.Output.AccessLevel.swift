extension Configuration.Output {
    /// Controls the access level of a Swift type such as a struct or a property
    public enum AccessLevel: Sendable {
        /// Applies an internal access level to a Swift type. Since internal is the default
        /// access level in Swift, an access level keyword will be ommitted from output source code
        case `internal`

        /// Applies a public access level to a Swift type. These locations will be visible outside the
        /// module in which the source code lives.
        case `public`
    }
}
