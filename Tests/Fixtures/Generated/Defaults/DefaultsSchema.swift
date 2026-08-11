// @generated

struct DefaultsInput: Encodable, Hashable, Sendable {

    let required: GraphQLHasDefault<Int>

    private let __optional: GraphQLNullable<Int>?

    @available(*, deprecated, message: "No longer supported")
    var optional: GraphQLNullable<Int>? { __optional }

    private let __list: GraphQLHasDefault<[GraphQLNullable<Int>?]>

    @available(*, deprecated, message: "")
    var list: GraphQLHasDefault<[GraphQLNullable<Int>?]> { __list }

    private enum CodingKeys: String, CodingKey {
        case required
        case __optional = "optional"
        case __list = "list"
    }

    init(
        required: GraphQLHasDefault<Int> = .useDefault /* 1 */,
        optional: GraphQLNullable<Int>? = nil /* 2 */,
        list: GraphQLHasDefault<[GraphQLNullable<Int>?]> = .useDefault /* [1] */
    ) {
        self.required = required
        self.__optional = optional
        self.__list = list
    }
}
