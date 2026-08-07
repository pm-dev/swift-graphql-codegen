struct GraphQLErrorWriter: APIOutput {
    let configuration: Configuration

    let relativePath = "GraphQLError.swift"
    let topLevelTypeNames = [SwiftTypeIdentifier(swiftName: "GraphQLError")]
    let typeReferences: Set<SwiftTypeReference> = [
        .init(.swift, "Decodable"),
        .init(.swift, "Decoder"),
        .init(.swift, "DecodingError"),
        .init(.swift, "Int"),
        .init(.swift, "Sendable"),
        .init(.swift, "String"),
    ]

    private var accessLevel: String {
        configuration.output.api.accessLevel == .public ? "public " : ""
    }

    private var header: String {
        guard let header = configuration.output.api.header else { return "" }
        return "\(header)\n\n"
    }

    var source: String {
        """
        \(header)/// https://spec.graphql.org/October2021/#sec-Errors
        \(accessLevel)struct GraphQLError: Decodable, Sendable {
            \(accessLevel)struct Location: Decodable, Sendable {
                \(accessLevel)let line: Int
                \(accessLevel)let column: Int
            }

            \(accessLevel)enum PathSegment: Decodable, Sendable {
                case listIndex(Int)
                case field(String)

                \(accessLevel)init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    if let stringValue = try? container.decode(String.self) {
                        self = .field(stringValue)
                    } else if let intValue = try? container.decode(Int.self) {
                        self = .listIndex(intValue)
                    } else {
                        throw DecodingError.dataCorruptedError(
                            in: container,
                            debugDescription: \"\"\"
                            Path segments that represent fields should be strings, and path segments that represent list indices should be 0-indexed integers.
                            https://spec.graphql.org/October2021/#sel-HAPHRPJABnEBpIx8Z
                            \"\"\"
                        )
                    }
                }
            }

            \(accessLevel)let message: String
            \(accessLevel)let locations: [Location]?
            \(accessLevel)let path: [PathSegment]?
            \(accessLevel)let extensions: [String: JSONValue]?
        }
        """
    }
}
