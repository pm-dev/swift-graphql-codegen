// @generated

public struct SetFavoriteEpisodeMutation: GraphQLMutation {

    public static let operationName: String? = "SetFavoriteEpisode"

    public static let document = #"""
    mutation SetFavoriteEpisode($episode:Episode!){setFavoriteEpisode(episode:$episode)}
    """#

    public let variables: Variables

    public let extensions: [String: AnyEncodable]?

    public init(
        episode: Episode,
        extensions: [String: AnyEncodable]? = nil
    ) {
        self.variables = Variables(
            episode: episode
        )
        self.extensions = extensions
    }

    public struct Variables: Encodable, Sendable {

        public let episode: Episode
    }

    public struct Data: Decodable, Sendable, Hashable {

        public let setFavoriteEpisode: GraphQLEnum<Episode>
    }
}
