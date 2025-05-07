// @generated

struct HeroQuery: GraphQLQuery {

    static let operationName: String? = "Hero"

    static let document = """
    query Hero($episode: Episode!) {
      hero(episode: $episode) {
        __typename
        ...jedi
        ...droid
      }
    }
    \(Jedi.source)
    \(Droid.source)
    \(Character.source)
    """

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

    struct Data: Decodable, Sendable {

        let hero: Hero

        struct Hero: Decodable, Sendable {

            let __typename: String

            let __jedi: Jedi?

            let __droid: Droid?

            init(from decoder: Decoder) throws {
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

struct Jedi: Decodable, Sendable, Hashable {

    static let source = """
    fragment jedi on Jedi {
      ...character
      lightSaberColor
    }
    """

    var __character: Character

    var lightSaberColor: String

    init(from decoder: Decoder) throws {
        enum CodingKeys: CodingKey {
            case lightSaberColor
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lightSaberColor = try container.decode(String.self, forKey: .lightSaberColor)
        __character = try Character(from: decoder)
    }
}

struct Droid: Decodable, Sendable, Hashable {

    static let source = """
    fragment droid on Droid {
      ...character
      primaryFunction
      operator
    }
    """

    var __character: Character

    var primaryFunction: String?

    var `operator`: String?

    init(from decoder: Decoder) throws {
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

struct Character: Decodable, Sendable, Hashable {

    static let source = """
    fragment character on Character {
      id
      name
    }
    """

    var id: ID

    var name: String
}

