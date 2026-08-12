extension Configuration.Input {
    /// Controls whether deprecated GraphQL schema members remain available to generated code.
    public enum DeprecationPolicy: Sendable {
        /// Include deprecated schema members. Generated declarations are annotated with a Swift warning where supported,
        /// and code generation warns when an operation uses a deprecated argument.
        case include

        /// Exclude deprecated schema members and fail code generation when an operation uses one.
        case exclude
    }
}
