// @generated

public struct HeroQuery: GraphQLQuery {

    public static let operationName: String? = "Hero"

    public static let document = #"""
    query Hero($episode:Episode!){hero(episode:$episode){__typename ...jedi ...droid}}fragment jedi on Jedi{...character lightSaberColor}fragment droid on Droid{...character primaryFunction operator}fragment character on Character{id name}
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

        public let hero: Hero

        public struct Hero: Decodable, Sendable, Hashable {

            public let __typename: String

            public let __jedi: Jedi?

            public let __droid: Droid?

            public init(from decoder: Decoder) throws {
                enum CodingKeys: CodingKey {
                    case __typename
                }
                let container = try decoder.container(keyedBy: CodingKeys.self)
                __typename = try container.decode(String.self, forKey: .__typename)
                __jedi = __typename == "Jedi" ? try Jedi(from: decoder) : nil
                __droid = __typename == "Droid" ? try Droid(from: decoder) : nil
            }
        }
    }
}

public struct Jedi: Decodable, Sendable, Hashable {

    public var __character: Character

    public var lightSaberColor: String

    public init(from decoder: Decoder) throws {
        enum CodingKeys: CodingKey {
            case lightSaberColor
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lightSaberColor = try container.decode(String.self, forKey: .lightSaberColor)
        __character = try Character(from: decoder)
    }
}

public struct Droid: Decodable, Sendable, Hashable {

    public var __character: Character

    public var primaryFunction: String?

    public var `operator`: String?

    public init(from decoder: Decoder) throws {
        enum CodingKeys: CodingKey {
            case primaryFunction
            case `operator`
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        primaryFunction = try container.decode(String?.self, forKey: .primaryFunction)
        `operator` = try container.decode(String?.self, forKey: .operator)
        __character = try Character(from: decoder)
    }
}

public struct Character: Decodable, Sendable, Hashable {

    public var id: ID

    public var name: String
}

