// @generated

struct SetFavoriteEpisodeMutation: GraphQLMutation {

    static let operationName: String? = "SetFavoriteEpisode"

    static let document = #"""
    mutation SetFavoriteEpisode($episode:Episode!){setFavoriteEpisode(episode:$episode)}
    """#

    let variables: Variables

    let extensions: [String: AnyEncodable]?

    init(
        episode: Episode,
        extensions: [String: AnyEncodable]? = nil
    ) {
        self.variables = Variables(
            episode: episode
        )
        self.extensions = extensions
    }

    struct Variables: Encodable, Sendable {

        let episode: Episode
    }

    struct Data: Decodable, Sendable, Hashable {

        let setFavoriteEpisode: GraphQLEnum<Episode>
    }
}

