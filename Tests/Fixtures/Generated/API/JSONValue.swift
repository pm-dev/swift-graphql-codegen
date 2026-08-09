// @generated

enum JSONValue: Decodable, Sendable {
    case map([String: JSONValue])
    case list([JSONValue])
    case null
    case string(String)
    case number(Double)
    case boolean(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .number(doubleValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .boolean(boolValue)
        } else if let arrayValue = try? container.decode([JSONValue].self) {
            self = .list(arrayValue)
        } else if let dictionaryValue = try? container.decode([String: JSONValue].self) {
            self = .map(dictionaryValue)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }
}