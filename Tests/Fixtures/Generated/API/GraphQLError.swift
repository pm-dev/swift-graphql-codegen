// @generated

/// https://spec.graphql.org/September2025/#sec-Errors
struct GraphQLError: Decodable, Sendable {
    struct Location: Decodable, Sendable {
        let line: Int
        let column: Int
    }

    enum PathSegment: Decodable, Sendable {
        case listIndex(Int)
        case field(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let stringValue = try? container.decode(String.self) {
                self = .field(stringValue)
            } else if let intValue = try? container.decode(Int.self), intValue >= 0 {
                self = .listIndex(intValue)
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: """
                    Path segments that represent fields should be strings, and path segments that represent list indices should be non-negative integers.
                    https://spec.graphql.org/September2025/#sec-Response-Position
                    """
                )
            }
        }
    }

    let message: String
    let locations: [Location]?
    let path: [PathSegment]?
    let extensions: [String: JSONValue]?
}