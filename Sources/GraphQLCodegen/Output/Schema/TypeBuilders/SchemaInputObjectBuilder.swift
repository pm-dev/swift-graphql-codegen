struct SchemaInputObjectBuilder: SwiftTypeBuildable {
    let inputObject: Schema.InputObject

    func build(configuration: Configuration) -> [String] {
        let isPublic = configuration.output.schema.accessLevel == .public
        var builder = SwiftStructBuilder()
        builder.start(
            description: inputObject.ast.description,
            isPublic: isPublic,
            structName: inputObject.ast.name,
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
                                    ".value(.useDefault) /* \(defaultValue.description) */"
                                } else {
                                    "nil"
                                }
                            case .list, .name:
                                if let defaultValue = inputField.defaultValue {
                                    ".useDefault /* \(defaultValue.description) */"
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
        type.swiftName.formatted(
            formatName: { defaultValue == nil ? $0 : "GraphQLHasDefault<\($0)>" },
            formatOptional: { "GraphQLNullable<\($0)>?" }
        )
    }
}
