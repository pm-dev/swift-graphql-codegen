struct GraphQLNullableWriter {
    let configuration: Configuration

    private var accessLevel: String {
        configuration.output.api.accessLevel == .public ? "public " : ""
    }

    private var header: String {
        guard let header = configuration.output.api.header else { return "" }
        return "\(header)\n\n"
    }

    func write() async throws {
        try await """
        \(header)\(accessLevel)enum GraphQLNullable<T>: Encodable, Hashable, Sendable where T: Encodable & Hashable & Sendable {
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
        """.write(
            to: configuration.output.api.directory.appending(
                path: "GraphQLNullable.swift",
                directoryHint: .notDirectory
            )
        )
    }
}
