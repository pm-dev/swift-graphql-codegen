// @generated

enum SearchFilterInput: Codable, Hashable, Sendable {
    case name(String)
    /// - Deprecated: Use name.
    indirect case search(SearchInput)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: __CodingKeys.self)
        let keys = container.allKeys
        guard keys.count == 1, let key = keys.first else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected exactly one field for SearchFilterInput."
                )
            )
        }
        switch key {
        case .name:
            self = .name(try container.decode(String.self, forKey: .name))
        case .search:
            self = .search(try container.decode(SearchInput.self, forKey: .search))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: __CodingKeys.self)
        switch self {
        case .name(let value):
            try container.encode(value, forKey: .name)
        case .search(let value):
            try container.encode(value, forKey: .search)
        }
    }

    private enum __CodingKeys: String, CodingKey {
        case name
        case search
    }
}
