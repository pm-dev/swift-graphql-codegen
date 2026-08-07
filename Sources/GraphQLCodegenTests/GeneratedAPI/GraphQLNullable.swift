// @generated

enum GraphQLNullable<T>: Encodable, Hashable, Sendable where T: Encodable & Hashable & Sendable {
    case null
    case value(T)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .value(let t): try container.encode(t)
        }
    }
}
