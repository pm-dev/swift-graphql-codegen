indirect enum SourceTypeName {
    case name(String)
    case optional(SourceTypeName)
    case list(SourceTypeName)

    init?(nativeGraphQLScalarName name: String) {
        switch name {
        case "String": self = .name("String")
        case "Int": self = .name("Int")
        case "Float": self = .name("Double")
        case "Boolean": self = .name("Bool")
        default: return nil
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

    func inputTypeName(hasDefaultValue: Bool) -> String {
        let typeName = formatted(
            formatName: { name in
                SwiftTypeIdentifier(swiftName: name).source
            },
            formatOptional: { "GraphQLNullable<\($0)>?" }
        )
        guard hasDefaultValue else { return typeName }
        switch self {
        case .optional: return typeName
        case .list, .name: return "GraphQLHasDefault<\(typeName)>"
        }
    }

    func requiredInputTypeName() -> String {
        switch self {
        case .optional(let inner): inner.inputTypeName(hasDefaultValue: false)
        case .list, .name: inputTypeName(hasDefaultValue: false)
        }
    }
}
