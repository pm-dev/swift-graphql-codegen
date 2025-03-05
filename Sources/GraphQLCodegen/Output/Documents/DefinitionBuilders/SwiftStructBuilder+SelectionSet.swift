import OrderedCollections

enum SelectionSetError: Error {
    case fragmentSpreadNeedsTypename(fragmentSpread: String)
    case selectionSetNeedsTypename(field: String, fragmentSpread: String)
}

extension SwiftStructBuilder {
    mutating func addSelectionSet(
        _ selectionSet: ResolvedSelectionSet,
        immutable: Bool,
        isPublic: Bool,
        conformances: [String],
        configuration: Configuration
    ) throws {
        var hasFields = false
        var hasFragments = false
        var hasNonnilTypenameField = false
        for (responseKey, selection) in selectionSet {
            switch selection {
            case .field(let field, let conditional):
                hasFields = true
                hasNonnilTypenameField = hasNonnilTypenameField || (responseKey == "__typename" && !conditional)
                let conditionalField = conditional ? field.asOptional() : field
                addProperty(
                    description: field.description,
                    deprecation: field.deprecation,
                    isPublic: isPublic,
                    isStatic: false,
                    immutable: immutable,
                    name: responseKey,
                    value: .unassigned(
                        type: conditionalField.sourceTypeName(responseKey: responseKey).formatted(),
                        initialized: nil
                    )
                )
            case .fragmentSpread(let fragmentSpreadName, let checkTypename):
                hasFragments = true
                addProperty(
                    description: nil,
                    deprecation: nil,
                    isPublic: isPublic,
                    isStatic: false,
                    immutable: immutable,
                    name: responseKey,
                    value: .unassigned(
                        type: fragmentSpreadName.capitalizedFirst + (checkTypename != nil ? "?" : ""),
                        initialized: nil
                    )
                )
            }
        }
        for (responseKey, selection) in selectionSet {
            switch selection {
            case .fragmentSpread: break
            case .field(let field, _):
                try addNestedStruct(
                    responseKey: responseKey,
                    for: field.type,
                    immutable: immutable,
                    isPublic: isPublic,
                    conformances: conformances,
                    configuration: configuration
                )
            }
        }
        try addSelectionSetInitializer(
            selectionSet,
            hasFragments: hasFragments,
            hasFields: hasFields,
            hasNonnilTypenameField: hasNonnilTypenameField,
            configuration: configuration
        )
    }

    private mutating func addNestedStruct(
        responseKey: String,
        for fieldType: ResolvedFieldType,
        immutable: Bool,
        isPublic: Bool,
        conformances: [String],
        configuration: Configuration
    ) throws {
        switch fieldType {
        case .scalar: break
        case .map(let map):
            var nestedStruct = SwiftStructBuilder()
            nestedStruct.start(
                description: nil,
                isPublic: isPublic,
                structName: responseKey.capitalizedFirst,
                conformances: conformances
            )
            do {
                try nestedStruct.addSelectionSet(
                    map,
                    immutable: immutable,
                    isPublic: isPublic,
                    conformances: conformances,
                    configuration: configuration
                )
            } catch {
                switch error as? SelectionSetError {
                case .fragmentSpreadNeedsTypename(let fragmentSpread):
                    throw SelectionSetError.selectionSetNeedsTypename(
                        field: responseKey,
                        fragmentSpread: fragmentSpread
                    )
                case .selectionSetNeedsTypename, .none: throw error
                }
            }
            addNestedType(nestedStruct)
        case .optional(let innerType):
            try addNestedStruct(
                responseKey: responseKey,
                for: innerType,
                immutable: immutable,
                isPublic: isPublic,
                conformances: conformances,
                configuration: configuration
            )
        case .list(let innerType):
            try addNestedStruct(
                responseKey: responseKey,
                for: innerType,
                immutable: immutable,
                isPublic: isPublic,
                conformances: conformances,
                configuration: configuration
            )
        }
    }

    private mutating func addSelectionSetInitializer(
        _ selectionSet: ResolvedSelectionSet,
        hasFragments: Bool,
        hasFields: Bool,
        hasNonnilTypenameField: Bool,
        configuration: Configuration
    ) throws {
        if hasFragments {
            addInitializerArguments(["from decoder: Decoder"])
            var initializerBody: [String] = []
            if hasFields {
                initializerBody.append("let container = try decoder.container(keyedBy: CodingKeys.self)")
            }
            var codingKeysEnum = hasFields ? SwiftEnumBuilder() : nil
            codingKeysEnum?.start(
                description: nil,
                isPublic: false,
                enumName: "CodingKeys",
                conformances: ["CodingKey"]
            )
            for (responseKey, selection) in selectionSet {
                switch selection {
                case .field(let field, let conditional):
                    var assignment = "\(responseKey) = "
                    assignment.append("try container.")
                    let typename: String
                    if conditional {
                        assignment.append("decodeIfPresent(")
                        typename = field.asNonOptional().sourceTypeName(responseKey: responseKey).formatted()
                    } else {
                        assignment.append("decode(")
                        typename = field.sourceTypeName(responseKey: responseKey).formatted()
                    }
                    assignment.append("\(typename).self, forKey: .\(responseKey))")
                    codingKeysEnum?.addCase(description: nil, deprecation: nil, name: responseKey)
                    initializerBody.append(assignment)
                case .fragmentSpread: break
                }
            }
            for (responseKey, selection) in selectionSet {
                switch selection {
                case .field: break
                case .fragmentSpread(let fragmentSpreadName, let checkTypename):
                    let fragmentTypeName = fragmentSpreadName.capitalizedFirst
                    var assignment = "\(responseKey) = "
                    if let checkTypename {
                        if !hasNonnilTypenameField {
                            throw SelectionSetError.fragmentSpreadNeedsTypename(fragmentSpread: fragmentSpreadName)
                        }
                        assignment.append("__typename == \"\(checkTypename)\" ? ")
                        assignment.append("try \(fragmentTypeName)(from: decoder) : nil")
                    } else {
                        assignment.append("try \(fragmentTypeName)(from: decoder)")
                    }
                    initializerBody.append(assignment)
                }
            }
            if let codingKeysEnum {
                initializerBody = codingKeysEnum.build(configuration: configuration) + initializerBody
            }
            addInitializerBody(initializerBody, isThrowing: true)
        }
    }
}
