struct SchemaInputObjectBuilder: SwiftTypeBuildable {
    let inputObject: Schema.InputObject
    let indirectInputFields: Set<String>

    func build(configuration: Configuration) -> [String] {
        if inputObject.ast.isOneOf {
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
            if let deprecation = inputField.deprecation {
                builder.addDeprecationDocumentation(deprecation.reason)
            }
            let indirect = indirectInputFields.contains(inputField.name) ? "indirect " : ""
            builder.addLine("\(indirect)case \(identifier(inputField.name))(\(inputField.oneOfTypeName))")
        }

        let includesDecodable = configuration.output.schema.inputObjects.conformances.contains { conformance in
            SwiftConformanceName(source: conformance).includesDecodable
        }
        if includesDecodable {
            addDecodableInitializer(
                to: &builder,
                accessLevel: accessLevel,
                indentation: indentation
            )
        }

        builder.addEmptyLine()
        builder.addLine("\(accessLevel)func encode(to encoder: Encoder) throws {")
        builder.addLine("\(indentation)var container = encoder.container(keyedBy: __CodingKeys.self)")
        builder.addLine("\(indentation)switch self {")
        for inputField in inputObject.ast.inputFields {
            let caseName = identifier(inputField.name)
            builder.addLine("\(indentation)case .\(caseName)(let value):")
            builder.addLine("\(indentation)\(indentation)try container.encode(value, forKey: .\(caseName))")
        }
        builder.addLine("\(indentation)}")
        builder.addLine("}")

        builder.addEmptyLine()
        builder.addLine("private enum __CodingKeys: String, CodingKey {")
        for inputField in inputObject.ast.inputFields {
            builder.addLine("\(indentation)case \(identifier(inputField.name))")
        }
        builder.addLine("}")
        return builder.build(configuration: configuration)
    }

    private func addDecodableInitializer(
        to builder: inout SwiftTypeBuilder,
        accessLevel: String,
        indentation: String
    ) {
        builder.addEmptyLine()
        builder.addLine("\(accessLevel)init(from decoder: Decoder) throws {")
        builder.addLine("\(indentation)let container = try decoder.container(keyedBy: __CodingKeys.self)")
        builder.addLine("\(indentation)let keys = container.allKeys")
        builder.addLine("\(indentation)guard keys.count == 1, let key = keys.first else {")
        builder.addLine("\(indentation)\(indentation)throw DecodingError.dataCorrupted(")
        builder.addLine("\(indentation)\(indentation)\(indentation)DecodingError.Context(")
        builder.addLine("\(indentation)\(indentation)\(indentation)\(indentation)codingPath: decoder.codingPath,")
        builder.addLine(
            "\(indentation)\(indentation)\(indentation)\(indentation)debugDescription: " +
                SwiftSource(value: "Expected exactly one field for \(inputObject.ast.name).").singleLineStringLiteral
        )
        builder.addLine("\(indentation)\(indentation)\(indentation))")
        builder.addLine("\(indentation)\(indentation))")
        builder.addLine("\(indentation)}")
        builder.addLine("\(indentation)switch key {")
        for inputField in inputObject.ast.inputFields {
            let caseName = identifier(inputField.name)
            builder.addLine("\(indentation)case .\(caseName):")
            builder.addLine(
                "\(indentation)\(indentation)self = .\(caseName)(" +
                    "try container.decode(\(inputField.oneOfTypeName).self, forKey: .\(caseName)))"
            )
        }
        builder.addLine("\(indentation)}")
        builder.addLine("}")
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
                deprecation: inputField.deprecation,
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
