struct AnyEncodableWriter: SupportOutput {
    let configuration: Configuration

    let topLevelTypeNames = [SwiftTypeIdentifier(swiftName: "AnyEncodable")]

    var source: String {
        """
        \(accessLevel)struct AnyEncodable: Encodable, Sendable {
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
