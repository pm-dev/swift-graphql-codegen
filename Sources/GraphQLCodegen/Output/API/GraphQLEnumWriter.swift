struct GraphQLEnumWriter {
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
        \(header)\(accessLevel)enum GraphQLEnum<T>: Decodable, Hashable, Sendable where T: Hashable & RawRepresentable & Sendable, T.RawValue == String {
            case known(T)
            case unknown(String)

            \(accessLevel)init(from decoder: Decoder) throws {
                let rawValue = try decoder.singleValueContainer().decode(String.self)
                if let value = T(rawValue: rawValue) {
                    self = .known(value)
                } else {
                    self = .unknown(rawValue)
                }
            }
        }

        """.write(
            to: configuration.output.api.directory.appending(
                path: "GraphQLEnum.swift",
                directoryHint: .notDirectory
            )
        )
    }
}
