// @generated

struct StateChangedSubscription: GraphQLSubscription {

    static let operationName: String? = "StateChanged"

    static let document = #"""
    subscription StateChanged{stateChanged}
    """#

    let variables: Never? = nil

    let extensions: [String: AnyEncodable]?

    init(extensions: [String: AnyEncodable]? = nil) {
        self.extensions = extensions
    }

    struct Data: Decodable, Sendable, Hashable {

        let stateChanged: GraphQLEnum<State>
    }
}
