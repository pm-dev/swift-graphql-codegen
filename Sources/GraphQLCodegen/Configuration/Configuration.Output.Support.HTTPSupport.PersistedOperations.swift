extension Configuration.Output.Support.HTTPSupport {
    /// Defines the different types of persisted operations.
    public enum PersistedOperations: Sendable {
        /// When `automatic` persisted operations is enabled, a hash of the GraphQL document
        /// is first sent to the server. If the server has already cached the GraphQL document for the
        /// given hash, the operation will be executed. Otherwise, the server will respond with an error
        /// and the client is expected to retry, this time with the full document (and hash).
        /// Automatic persisted operations reduce network overhead but do not provide additional security.
        /// Note: A DDOS attack could spam your cached operations, negating advantages of this strategy
        /// and reducing performance by forcing two round trips.
        /// To learn more about automatic persisted operations:
        /// https://the-guild.dev/graphql/yoga-server/docs/features/automatic-persisted-queries
        case automatic

        /// When `registered` persisted operations is enabled, a hash of the GraphQL document
        /// is sent to the server instead of the full document, which the server is always expected to already have stored.
        /// Generate and publish a persisted-operation manifest separately with
        /// `Codegen.generatePersistedOperationManifestFile(at:)`.
        /// This adds a layer of security by preventing unknown operations from being executed by the server. It also
        /// can improve performance because servers no longer need to validate operations at request time.
        /// Set `allowUnregisteredOperations` to `true` to expose a runtime option for sending the full document
        /// instead of its registered hash, which is useful when developing against an unregistered server.
        /// To learn more about automatic persisted operations:
        /// https://the-guild.dev/graphql/yoga-server/docs/features/persisted-operations
        case registered(
            allowUnregisteredOperations: Bool = false
        )
    }
}
