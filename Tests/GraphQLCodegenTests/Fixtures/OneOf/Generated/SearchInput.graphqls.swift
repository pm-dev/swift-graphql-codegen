// @generated

enum SearchInput: Encodable, Hashable, Sendable {
    case id(Int)
    case name(String)
    case tags([String])

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .id(let value):
            try container.encode(value, forKey: .id)
        case .name(let value):
            try container.encode(value, forKey: .name)
        case .tags(let value):
            try container.encode(value, forKey: .tags)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case tags
    }
}
