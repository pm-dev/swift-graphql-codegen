// @generated

struct AnyEncodable: Encodable, Sendable {
    private let encoder: @Sendable (Encoder) throws -> Void
    init<T: Encodable & Sendable>(_ value: T) {
        self.encoder = { encoder in try value.encode(to: encoder) }
    }
    init?<T: Encodable & Sendable>(_ value: T?) {
        guard let value else { return nil }
        self.encoder = { encoder in try value.encode(to: encoder) }
    }
    func encode(to encoder: Encoder) throws {
        try self.encoder(encoder)
    }
}
