// @generated

struct AnyEncodable: Encodable, Sendable {
    private let encoder: @Sendable (Encoder) throws -> Void
    init<T: Encodable & Sendable>(_ value: T) {
        self.encoder = value.encode(to:)
    }
    init?<T: Encodable & Sendable>(_ value: T?) {
        guard let value else { return nil }
        self.encoder = value.encode(to:)
    }
    func encode(to encoder: Encoder) throws {
        try self.encoder(encoder)
    }
}