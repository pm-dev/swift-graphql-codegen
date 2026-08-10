// @generated

/// https://spec.graphql.org/September2025/#sec-Errors
public struct GraphQLError: Decodable, Sendable {
    public struct Location: Decodable, Sendable {
        public let line: Int
        public let column: Int
    }

    public enum PathSegment: Decodable, Sendable {
        case listIndex(Int)
        case field(String)

        public init(from decoder: Decoder) throws {
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

    public let message: String
    public let locations: [Location]?
    public let path: [PathSegment]?
    public let extensions: [String: JSONValue]?
}