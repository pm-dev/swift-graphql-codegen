struct AnyEncodableWriter {
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
        \(header)\(accessLevel)struct AnyEncodable: Encodable, Sendable {
            private let encoder: @Sendable (Encoder) throws -> Void
            \(accessLevel)init<T: Encodable & Sendable>(_ value: T) {
                self.encoder = value.encode(to:)
            }
            \(accessLevel)init?<T: Encodable & Sendable>(_ value: T?) {
                guard let value else { return nil }
                self.encoder = value.encode(to:)
            }
            \(accessLevel)func encode(to encoder: Encoder) throws {
                try self.encoder(encoder)
            }
        }
        """.write(
            to: configuration.output.api.directory.appending(
                path: "AnyEncodable.swift",
                directoryHint: .notDirectory
            )
        )
    }
}
