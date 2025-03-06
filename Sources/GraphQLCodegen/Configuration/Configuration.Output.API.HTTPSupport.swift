extension Configuration.Output.API {
    /// Options controlling API files that generated to support HTTP requests to GraphQL servers.
    ///
    /// These files ensure requests conform to the GraphQL over HTTP spec:
    /// https://graphql.github.io/graphql-over-http/draft/#sec-GraphQL-over-HTTP
    ///
    /// Codegen will use options from `Configuration` to craft Networking APIs specifically to your
    /// use case. For example, if `Operations.persistedOperations` is `nil` the generated
    /// APIs for creating a GraphQL request will not include those options.
    public struct HTTPSupport: Sendable {
        /// Call this function to create a new `HTTPSupport` instance.
        ///
        /// - Parameters:
        ///   - enableGETQueries: Pass `true` to enable making `query` operation requests using the HTTP GET
        ///   method. Passing `false` will ensure all operation requests are made using the HTTP POST method
        ///   - subscriptionSupport: Pass `true` to enable support for subscription operations via GraphQL over Server-Sent Events:
        ///   https://github.com/enisdenjo/graphql-sse/blob/master/PROTOCOL.md#distinct-connections-mode. If your
        ///   graphql documents include one or more subscription operations, this will add a `subscribe` function to the generated URLSession
        ///   extension.
        /// - Returns: A new `HTTPSupport` instance to be passed to the `API.api` factory function.
        public static func httpSupport(
            enableGETQueries: Bool = false,
            subscriptionSupport: Bool = false
        ) -> HTTPSupport {
            HTTPSupport(
                enableGETQueries: enableGETQueries,
                subscriptionSupport: subscriptionSupport
            )
        }

        public var enableGETQueries: Bool
        public var subscriptionSupport: Bool
    }
}
