struct GraphQLNullableWriter: APIOutput {
    let configuration: Configuration
    let requiresIndirectNullable: Bool

    let relativePath = "GraphQLNullable.swift"
    let topLevelTypeNames = [SwiftTypeIdentifier(swiftName: "GraphQLNullable")]
    let typeReferences: Set<SwiftTypeReference> = [
        .init(.swift, "Encodable"),
        .init(.swift, "Encoder"),
        .init(.swift, "Hashable"),
        .init(.swift, "Sendable"),
    ]

    private var accessLevel: String {
        configuration.output.api.accessLevel == .public ? "public " : ""
    }

    private var header: String {
        guard let header = configuration.output.api.header else { return "" }
        return "\(header)\n\n"
    }

    var source: String {
        let indirect = requiresIndirectNullable ? "indirect " : ""
        return """
        \(header)\(accessLevel)\(indirect)enum GraphQLNullable<T>: Encodable, Hashable, Sendable where T: Encodable & Hashable & Sendable {
            case null
            case value(T)

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
