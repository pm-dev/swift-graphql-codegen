import LetterCase

struct SchemaEnumBuilder: SwiftTypeBuildable {
    let `enum`: Schema.Enum
    let configuration: Configuration

    func build(configuration: Configuration) -> [String] {
        var builder = SwiftEnumBuilder()
        builder.start(
            description: `enum`.ast.description,
            isPublic: configuration.output.schema.accessLevel == .public,
            enumName: `enum`.ast.name,
            conformances: ["String"] + configuration.output.schema.enums.conformances
        )
        for enumValue in `enum`.ast.enumValues {
            let caseName: String
            if let caseConverstion = configuration.output.schema.enums.caseConversion {
                caseName = enumValue.name.convert(
                    from: caseConverstion.from.letterCase,
                    to: caseConverstion.to.letterCase
                )
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

extension Configuration.Output.Schema.Enums.CaseConversion.Case {
    var letterCase: LetterCase {
        switch self {
        case .lowerCamel: .lowerCamel
        case .macro: .macro
        }
    }
}
