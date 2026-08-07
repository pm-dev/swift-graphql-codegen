// @generated

struct DefaultsInput: Encodable, Hashable, Sendable {

    let required: GraphQLHasDefault<Int>

    let optional: GraphQLNullable<Int>?

    let list: GraphQLHasDefault<[GraphQLNullable<Int>?]>

    init(
        required: GraphQLHasDefault<Int> = .useDefault /* 1 */,
        optional: GraphQLNullable<Int>? = nil /* 2 */,
        list: GraphQLHasDefault<[GraphQLNullable<Int>?]> = .useDefault /* [1] */
    ) {
        self.required = required
        self.optional = optional
        self.list = list
    }
}
