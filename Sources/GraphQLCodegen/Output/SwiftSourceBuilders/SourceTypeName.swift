indirect enum SourceTypeName {
    case name(String)
    case optional(SourceTypeName)
    case list(SourceTypeName)

    static func swiftNativeScalar(graphQLScalarName: String) -> String? {
        switch graphQLScalarName {
        case "String": "String"
        case "Int": "Int"
        case "Float": "Double"
        case "Boolean": "Bool"
        default: nil
        }
    }
}

extension SourceTypeName {
    static let swiftOptionalConversion: @Sendable (String) -> String = { $0 + "?" }
    static let swiftListConversion: @Sendable (String) -> String = { "[" + $0 + "]" }

    func formatted(
        formatName: (String) -> String = { $0 },
        formatOptional: (String) -> String = swiftOptionalConversion,
        formatList: (String) -> String = swiftListConversion
    ) -> String {
        switch self {
        case .name(let string):
            formatName(string)
        case .optional(let inner):
            formatOptional(
                inner.formatted(
                    formatName: formatName,
                    formatOptional: formatOptional,
                    formatList: formatList
                )
            )
        case .list(let inner):
            formatList(
                inner.formatted(
                    formatName: formatName,
                    formatOptional: formatOptional,
                    formatList: formatList
                )
            )
        }
    }
}
