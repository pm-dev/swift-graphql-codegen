// @generated

struct NodeQuery: GraphQLQuery {

    static let operationName: String? = "Node"

    static let document = #"""
    query Node($state:State!){node(state:$state){__typename ...person ...service}}fragment person on Person{...entityFields email}fragment service on Service{...entityFields purpose owner}fragment entityFields on Entity{id name}
    """#

    let variables: Variables

    let extensions: [String: AnyEncodable]?

    init(
        state: State,
        extensions: [String: AnyEncodable]? = nil
    ) {
        self.variables = Variables(
            state: state
        )
        self.extensions = extensions
    }

    struct Variables: Encodable, Sendable {

        let state: State
    }

    struct Data: Decodable, Sendable, Hashable {

        let node: Node

        struct Node: Decodable, Sendable, Hashable {

            let __typename: String

            let __person: Person?

            let __service: Service?

            init(from decoder: Decoder) throws {
                enum CodingKeys: CodingKey {
                    case __typename
                }
                let container = try decoder.container(keyedBy: CodingKeys.self)
                __typename = try container.decode(String.self, forKey: .__typename)
                __person = __typename == "Person" ? try Person(from: decoder) : nil
                __service = __typename == "Service" ? try Service(from: decoder) : nil
            }
        }
    }
}

struct Person: Decodable, Sendable, Hashable {

    var __entityFields: EntityFields

    var email: String

    init(from decoder: Decoder) throws {
        enum CodingKeys: CodingKey {
            case email
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        email = try container.decode(String.self, forKey: .email)
        __entityFields = try EntityFields(from: decoder)
    }
}

struct Service: Decodable, Sendable, Hashable {

    var __entityFields: EntityFields

    var purpose: String?

    var owner: String?

    init(from decoder: Decoder) throws {
        enum CodingKeys: CodingKey {
            case purpose
            case owner
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        purpose = try container.decode(String?.self, forKey: .purpose)
        owner = try container.decode(String?.self, forKey: .owner)
        __entityFields = try EntityFields(from: decoder)
    }
}

struct EntityFields: Decodable, Sendable, Hashable {

    var id: ID

    var name: String
}

