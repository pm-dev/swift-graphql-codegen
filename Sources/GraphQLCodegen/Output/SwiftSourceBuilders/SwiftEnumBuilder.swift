struct SwiftEnumBuilder: SwiftTypeBuildable {
    private var builder: SwiftTypeBuilder

    init(
        description: String?,
        isPublic: Bool,
        name: String,
        conformances: [String]
    ) {
        builder = SwiftTypeBuilder(
            description: description,
            isPublic: isPublic,
            type: "enum",
            name: identifier(name),
            conformances: conformances
        )
    }

    func build(configuration: Configuration) -> [String] {
        builder.build(configuration: configuration)
    }

    mutating func addCase(
        description: String?,
        deprecation: Deprecation?,
        name: String,
        rawValue: String? = nil
    ) {
        if let description {
            builder.addComment(description)
        }
        if let deprecation {
            builder.addDeprecation(deprecation.reason)
        }
        var declaration = "case \(identifier(name))"
        if let rawValue {
            declaration.append(" = \(SwiftSource(value: rawValue).singleLineStringLiteral)")
        }
        builder.addLine(declaration)
    }
}
