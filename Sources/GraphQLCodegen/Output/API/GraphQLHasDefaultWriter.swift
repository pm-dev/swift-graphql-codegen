struct GraphQLHasDefaultWriter {
    let configuration: Configuration

    private var accessLevel: String {
        configuration.output.api.accessLevel == .public ? "public " : ""
    }

    private var header: String {
        guard let header = configuration.output.api.header else { return "" }
        return "\(header)\n\n"
    }

    func write(using fileOutput: FileOutput) async throws {
        try await """
        \(header)\(accessLevel)enum GraphQLHasDefault<T>: Encodable, Hashable, Sendable where T: Encodable & Hashable & Sendable {
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
        """.write(
            to: configuration.output.api.directory.appending(
                path: "GraphQLHasDefault.swift",
                directoryHint: .notDirectory
            ),
            using: fileOutput
        )
    }
}
