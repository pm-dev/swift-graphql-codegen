// @generated

enum SearchInput: Codable, Hashable, Sendable {
    case id(Int)
    /// - Deprecated: Use id.
    case name(String)
    case tags([String])
    indirect case next(SearchInput)
    indirect case filter(SearchFilterInput)
    case CodingKeys(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: __CodingKeys.self)
        let keys = container.allKeys
        guard keys.count == 1, let key = keys.first else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected exactly one field for SearchInput."
                )
            )
        }
        switch key {
        case .id:
            self = .id(try container.decode(Int.self, forKey: .id))
        case .name:
            self = .name(try container.decode(String.self, forKey: .name))
        case .tags:
            self = .tags(try container.decode([String].self, forKey: .tags))
        case .next:
            self = .next(try container.decode(SearchInput.self, forKey: .next))
        case .filter:
            self = .filter(try container.decode(SearchFilterInput.self, forKey: .filter))
        case .CodingKeys:
            self = .CodingKeys(try container.decode(String.self, forKey: .CodingKeys))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: __CodingKeys.self)
        switch self {
        case .id(let value):
            try container.encode(value, forKey: .id)
        case .name(let value):
            try container.encode(value, forKey: .name)
        case .tags(let value):
            try container.encode(value, forKey: .tags)
        case .next(let value):
            try container.encode(value, forKey: .next)
        case .filter(let value):
            try container.encode(value, forKey: .filter)
        case .CodingKeys(let value):
            try container.encode(value, forKey: .CodingKeys)
        }
    }

    private enum __CodingKeys: String, CodingKey {
        case id
        case name
        case tags
        case next
        case filter
        case CodingKeys
    }
}
