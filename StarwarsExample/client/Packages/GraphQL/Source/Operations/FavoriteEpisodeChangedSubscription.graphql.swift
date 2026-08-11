// @generated

public struct FavoriteEpisodeChangedSubscription: GraphQLSubscription {

    public static let operationName: String? = "FavoriteEpisodeChanged"

    public static let document = #"""
    subscription FavoriteEpisodeChanged{favoriteEpisodeChanged}
    """#

    public let variables: Never? = nil

    public let extensions: [String: AnyEncodable]?

    public init(extensions: [String: AnyEncodable]? = nil) {
        self.extensions = extensions
    }

    public struct Data: Decodable, Sendable, Hashable {

        public let favoriteEpisodeChanged: GraphQLEnum<Episode>
    }
}
