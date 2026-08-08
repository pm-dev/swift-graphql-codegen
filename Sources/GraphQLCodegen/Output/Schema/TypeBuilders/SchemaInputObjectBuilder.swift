struct SchemaInputObjectBuilder: SwiftTypeBuildable {
    let inputObject: Schema.InputObject

    func build(configuration: Configuration) -> [String] {
        if inputObject.ast.isOneOf == true {
            return buildOneOf(configuration: configuration)
        }

        return buildStruct(configuration: configuration)
    }

    private func buildOneOf(configuration: Configuration) -> [String] {
        let isPublic = configuration.output.schema.accessLevel == .public
        let accessLevel = isPublic ? "public " : ""
        let indentation = configuration.output.indentation.string
        var builder = SwiftTypeBuilder(
            description: inputObject.ast.description,
            isPublic: isPublic,
            type: "enum",
            name: SwiftTypeIdentifier(swiftName: inputObject.ast.name).source,
            conformances: configuration.output.schema.inputObjects.conformances
        )
        for inputField in inputObject.ast.inputFields {
            if let description = inputField.description, !description.isEmpty {
                builder.addComment(description)
            }
            builder.addLine("case \(identifier(inputField.name))(\(inputField.oneOfTypeName))")
        }

        builder.addEmptyLine()
        builder.addLine("\(accessLevel)func encode(to encoder: Encoder) throws {")
        builder.addLine("\(indentation)var container = encoder.container(keyedBy: CodingKeys.self)")
        builder.addLine("\(indentation)switch self {")
        for inputField in inputObject.ast.inputFields {
            let caseName = identifier(inputField.name)
            builder.addLine("\(indentation)case .\(caseName)(let value):")
            builder.addLine("\(indentation)\(indentation)try container.encode(value, forKey: .\(caseName))")
        }
        builder.addLine("\(indentation)}")
        builder.addLine("}")

        builder.addEmptyLine()
        builder.addLine("private enum CodingKeys: String, CodingKey {")
        for inputField in inputObject.ast.inputFields {
            builder.addLine("\(indentation)case \(identifier(inputField.name))")
        }
        builder.addLine("}")
        return builder.build(configuration: configuration)
    }

    private func buildStruct(configuration: Configuration) -> [String] {
        let isPublic = configuration.output.schema.accessLevel == .public
        var builder = SwiftStructBuilder(
            description: inputObject.ast.description,
            isPublic: isPublic,
            name: SwiftTypeIdentifier(swiftName: inputObject.ast.name).source,
            conformances: configuration.output.schema.inputObjects.conformances
        )
        for inputField in inputObject.ast.inputFields {
            builder.addProperty(
                description: inputField.description,
                deprecation: nil,
                isPublic: isPublic,
                isStatic: false,
                immutable: configuration.output.schema.inputObjects.immutable,
                name: inputField.name,
                value: .unassigned(
                    type: inputField.typeName,
                    initialized: .direct(
                        defaultValue: {
                            switch inputField.type.swiftName {
                            case .optional:
                                if let defaultValue = inputField.defaultValue {
                                    "nil \(SwiftSource(value: defaultValue.description).blockComment)"
                                } else {
                                    "nil"
                                }
                            case .list, .name:
                                if let defaultValue = inputField.defaultValue {
                                    ".useDefault \(SwiftSource(value: defaultValue.description).blockComment)"
                                } else {
                                    nil
                                }
                            }
                        }()
                    )
                )
            )
        }
        return builder.build(configuration: configuration)
    }
}

extension __Schema.__InputValue {
    var typeName: String {
        type.swiftName.inputTypeName(hasDefaultValue: defaultValue != nil)
    }

    var oneOfTypeName: String {
        type.swiftName.requiredInputTypeName()
    }
}
