struct GraphQLHasDefaultWriter: SupportOutput {
    let configuration: Configuration

    let topLevelTypeNames = [SwiftTypeIdentifier(swiftName: "GraphQLHasDefault")]

    var source: String {
        """
        \(accessLevel)enum GraphQLHasDefault<T>: Encodable, Hashable, Sendable where T: Encodable & Hashable & Sendable {
            case useDefault
            case value(T)

            \(accessLevel)func encode(to encoder: Encoder) throws {
                switch self {
                case .useDefault:
                    throw EncodingError.invalidValue(
                        self,
                        EncodingError.Context(
                            codingPath: encoder.codingPath,
                            debugDescription: "GraphQLHasDefault.useDefault must be encoded from a keyed container."
                        )
                    )
                case .value(let value):
                    var container = encoder.singleValueContainer()
                    try container.encode(value)
                }
            }
        }

        extension KeyedEncodingContainer {
            \(accessLevel)mutating func encode<T>(
                _ value: GraphQLHasDefault<T>,
                forKey key: Key
            ) throws where T: Encodable & Hashable & Sendable {
                switch value {
                case .useDefault: break
                case .value(let value): try encode(value, forKey: key)
                }
            }
        }
        """
    }
}
