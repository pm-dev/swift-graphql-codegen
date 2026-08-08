struct SchemaEnumBuilder: SwiftTypeBuildable {
    let `enum`: Schema.Enum

    func build(configuration: Configuration) -> [String] {
        let caseConversion = configuration.output.schema.enums.caseConversion
        var builder = SwiftEnumBuilder(
            description: `enum`.ast.description,
            isPublic: configuration.output.schema.accessLevel == .public,
            name: SwiftTypeIdentifier(swiftName: `enum`.ast.name).source,
            conformances: ["String"] + configuration.output.schema.enums.conformances
        )
        for enumValue in `enum`.ast.enumValues {
            let caseName = caseConversion?.convert(enumValue.name) ?? enumValue.name
            builder.addCase(
                description: enumValue.description,
                deprecation: enumValue.isDeprecated ? Deprecation(reason: enumValue.deprecationReason) : nil,
                name: caseName,
                rawValue: caseConversion == nil ? nil : enumValue.name
            )
        }
        return builder.build(configuration: configuration)
    }
}
