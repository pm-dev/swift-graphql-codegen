// @generated

struct SetStateMutation: GraphQLMutation {

    static let operationName: String? = "SetState"

    static let document = #"""
    mutation SetState($state:State!){setState(state:$state)}
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

        let setState: GraphQLEnum<State>
    }
}

