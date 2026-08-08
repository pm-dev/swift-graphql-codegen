// @generated

struct DefaultsQuery {

    static let operationName: String? = "Defaults"

    static let document = #"""
    query Defaults(
      $input: DefaultsInput! = {}
      $required: Int! = 1
      $optional: Int = 2
      $list: [Int]! = [1]
    ) {
      defaults(
        input: $input
        required: $required
        optional: $optional
        list: $list
      )
    }
    """#

    static let minifiedDocument = #"""
    query Defaults($input:DefaultsInput!={}$required:Int!=1$optional:Int=2$list:[Int]!=[1]){defaults(input:$input required:$required optional:$optional list:$list)}
    """#

    let variables: Variables

    let extensions: [String: AnyEncodable]?

    init(
        input: GraphQLHasDefault<DefaultsInput> = .useDefault /* [] */,
        required: GraphQLHasDefault<Int> = .useDefault /* 1 */,
        optional: GraphQLNullable<Int>? = nil /* 2 */,
        list: GraphQLHasDefault<[GraphQLNullable<Int>?]> = .useDefault /* [1] */,
        extensions: [String: AnyEncodable]? = nil
    ) {
        self.variables = Variables(
            input: input,
            required: required,
            optional: optional,
            list: list
        )
        self.extensions = extensions
    }

    struct Variables: Encodable, Sendable {

        let input: GraphQLHasDefault<DefaultsInput>

        let required: GraphQLHasDefault<Int>

        let optional: GraphQLNullable<Int>?

        let list: GraphQLHasDefault<[GraphQLNullable<Int>?]>
    }

    struct Data: Decodable, Sendable, Hashable {

        let defaults: Int
    }
}
