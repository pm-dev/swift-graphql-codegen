struct AnyEncodableWriter: APIOutput {
    let configuration: Configuration

    let relativePath = "AnyEncodable.swift"
    let topLevelTypeNames = [SwiftTypeIdentifier(swiftName: "AnyEncodable")]

    private var accessLevel: String {
        configuration.output.api.accessLevel == .public ? "public " : ""
    }

    private var header: String {
        guard let header = configuration.output.api.header else { return "" }
        return "\(header)\n\n"
    }

    var source: String {
        """
        \(header)\(accessLevel)struct AnyEncodable: Encodable, Sendable {
            private let encoder: @Sendable (Encoder) throws -> Void
            \(accessLevel)init<T: Encodable & Sendable>(_ value: T) {
                self.encoder = { encoder in try value.encode(to: encoder) }
            }
            \(accessLevel)init?<T: Encodable & Sendable>(_ value: T?) {
                guard let value else { return nil }
                self.encoder = { encoder in try value.encode(to: encoder) }
            }
            \(accessLevel)func encode(to encoder: Encoder) throws {
                try self.encoder(encoder)
            }
        }
        """
    }
}
