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
        name: String
    ) {
        if let description {
            builder.addComment(description)
        }
        if let deprecation {
            builder.addDeprecation(deprecation.reason)
        }
        builder.addLine("case \(identifier(name))")
    }
}
