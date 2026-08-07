// @generated

struct FavoriteEpisodeChangedSubscription: GraphQLSubscription {

    static let operationName: String? = "FavoriteEpisodeChanged"

    static let document = #"""
    subscription FavoriteEpisodeChanged {
      favoriteEpisodeChanged
    }
    """#

    static let minifiedDocument = #"""
    subscription FavoriteEpisodeChanged{favoriteEpisodeChanged}
    """#

    let variables: Never? = nil

    let extensions: [String: AnyEncodable]?

    init(extensions: [String: AnyEncodable]? = nil) {
        self.extensions = extensions
    }

    struct Data: Decodable, Sendable, Hashable {

        let favoriteEpisodeChanged: GraphQLEnum<Episode>
    }
}

