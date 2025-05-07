struct SwiftEnumBuilder: SwiftTypeBuildable {
    private var builder = SwiftTypeBuilder()

    func build(configuration: Configuration) -> [String] {
        builder.build(configuration: configuration)
    }

    mutating func start(
        description: String?,
        isPublic: Bool,
        enumName: String,
        conformances: [String]
    ) {
        builder.start(
            description: description,
            isPublic: isPublic,
            type: "enum",
            name: identifier(enumName),
            conformances: conformances
        )
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
