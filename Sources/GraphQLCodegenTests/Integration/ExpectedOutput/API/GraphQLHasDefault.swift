// @generated

enum GraphQLHasDefault<T>: Encodable, Hashable where T: Encodable, T: Hashable {
    case useDefault
    case value(T)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .useDefault: break
        case .value(let t): try container.encode(t)
        }
    }
}