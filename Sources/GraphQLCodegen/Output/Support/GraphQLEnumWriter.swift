struct GraphQLEnumWriter: SupportOutput {
    let configuration: Configuration

    let topLevelTypeNames = [SwiftTypeIdentifier(swiftName: "GraphQLEnum")]

    var source: String {
        """
        \(accessLevel)enum GraphQLEnum<T>: Decodable, Hashable, Sendable where T: Hashable & RawRepresentable & Sendable, T.RawValue == String {
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
        """
    }
}
