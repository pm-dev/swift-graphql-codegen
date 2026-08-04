// @generated

struct HeroQuery: GraphQLQuery {

    static let operationName: String? = "Hero"

    static let document = #"""
    query Hero($episode: Episode!) {
      hero(episode: $episode) {
        __typename
        ...jedi
        ...droid
      }
    }
    fragment jedi on Jedi {
      ...character
      lightSaberColor
    }
    fragment droid on Droid {
      ...character
      primaryFunction
      operator
    }
    fragment character on Character {
      id
      name
    }
    """#

    static let minifiedDocument = #"""
    query Hero($episode:Episode!){hero(episode:$episode){__typename ...jedi ...droid}}fragment jedi on Jedi{...character lightSaberColor}fragment droid on Droid{...character primaryFunction operator}fragment character on Character{id name}
    """#

    static let documentHash = "b677ac6b774c2f737e77bbc61b9f12e8337d5eb86231eba2010da1396c50fae5"

    static let minifiedDocumentHash = "4e3cbd0a2b22a963217d4ed95e43cbc301eb0b46c36bfa1fdfd9cecfbda148b5"

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

        let hero: Hero

        struct Hero: Decodable, Sendable, Hashable {

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

    var id: ID

    var name: String
}

