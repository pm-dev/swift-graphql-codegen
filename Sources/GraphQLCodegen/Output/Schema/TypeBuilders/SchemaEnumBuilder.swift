struct SchemaEnumBuilder: SwiftTypeBuildable {
    let `enum`: Schema.Enum

    func build(configuration: Configuration) -> [String] {
        var builder = SwiftEnumBuilder()
        builder.start(
            description: `enum`.ast.description,
            isPublic: configuration.output.schema.accessLevel == .public,
            enumName: `enum`.ast.name,
            conformances: ["String"] + configuration.output.schema.enums.conformances
        )
        for enumValue in `enum`.ast.enumValues {
            builder.addCase(
                description: enumValue.description,
                deprecation: enumValue.isDeprecated ? Deprecation(reason: enumValue.deprecationReason) : nil,
                name: enumValue.name
            )
        }
        return builder.build(configuration: configuration)
    }
}
