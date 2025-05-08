struct GraphQLHasDefaultWriter {
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
        \(header)\(accessLevel)enum GraphQLHasDefault<T>: Encodable, Hashable where T: Encodable & Hashable & Sendable {
            case useDefault
            case value(T)

            \(accessLevel)func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .useDefault: break
                case .value(let t): try container.encode(t)
                }
            }
        }
        """.write(
            to: configuration.output.api.directory.appending(
                path: "GraphQLHasDefault.swift",
                directoryHint: .notDirectory
            )
        )
    }
}
