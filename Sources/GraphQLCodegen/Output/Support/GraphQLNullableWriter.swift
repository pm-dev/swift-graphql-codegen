struct GraphQLNullableWriter: SupportOutput {
    let configuration: Configuration
    let requiresIndirectNullable: Bool

    let topLevelTypeNames = [SwiftTypeIdentifier(swiftName: "GraphQLNullable")]

    var source: String {
        let indirectCase = requiresIndirectNullable ? "indirect " : ""
        return """
        \(accessLevel)enum GraphQLNullable<T>: Encodable, Hashable, Sendable where T: Encodable & Hashable & Sendable {
            case null
            \(indirectCase)case value(T)

            \(accessLevel)func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .null: try container.encodeNil()
                case .value(let t): try container.encode(t)
                }
            }
        }
        """
    }
}
