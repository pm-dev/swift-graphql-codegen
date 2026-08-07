struct SchemaEnumBuilder: SwiftTypeBuildable {
    let `enum`: Schema.Enum
    let configuration: Configuration

    func build(configuration: Configuration) -> [String] {
        var builder = SwiftEnumBuilder(
            description: `enum`.ast.description,
            isPublic: configuration.output.schema.accessLevel == .public,
            name: SwiftTypeIdentifier(swiftName: `enum`.ast.name).source,
            conformances: ["String"] + configuration.output.schema.enums.conformances
        )
        for enumValue in `enum`.ast.enumValues {
            let caseName: String
            if let caseConversion = configuration.output.schema.enums.caseConversion {
                caseName = caseConversion.convert(enumValue.name)
            } else {
                caseName = enumValue.name
            }
            builder.addCase(
                description: enumValue.description,
                deprecation: enumValue.isDeprecated ? Deprecation(reason: enumValue.deprecationReason) : nil,
                name: caseName
            )
        }
        return builder.build(configuration: configuration)
    }
}
