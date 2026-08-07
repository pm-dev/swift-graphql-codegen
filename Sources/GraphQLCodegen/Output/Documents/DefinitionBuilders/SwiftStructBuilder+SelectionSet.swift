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
        conformances: OrderedSet<String>,
        configuration: Configuration,
        typeScope: SwiftTypeScope
    ) throws {
        let typePlan = SelectionSetTypePlan(selectionSet: selectionSet, conformances: conformances)
        let selectionTypeScope = typeScope.adding(declarations: typePlan.declarations.map(\.name))

        var hasNonnilTypenameField = false
        for (responseKey, selection) in selectionSet {
            switch selection {
            case .field(let field, let conditional):
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
                        type: conditionalField.sourceTypeName(
                            responseKey: responseKey,
                            typeScope: selectionTypeScope
                        ).formatted(),
                        initialized: configuration.output.documents.memberwiseInitializer ?
                            .direct(defaultValue: nil) : nil
                    )
                )
            case .fragmentSpread(let fragmentSpreadName, let checkTypename):
                addProperty(
                    description: nil,
                    deprecation: nil,
                    isPublic: isPublic,
                    isStatic: false,
                    immutable: immutable,
                    name: responseKey,
                    value: .unassigned(
                        type: SwiftTypeIdentifier(capitalizing: fragmentSpreadName).source +
                            (checkTypename != nil ? "?" : ""),
                        initialized: configuration.output.documents.memberwiseInitializer ?
                            .direct(defaultValue: nil) : nil
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
                    configuration: configuration,
                    typeScope: selectionTypeScope
                )
            }
        }
        let includesDecodable = conformances.contains { conformance in
            SwiftConformanceName(source: conformance).includesDecodable
        }
        if typePlan.hasFragments, includesDecodable {
            try addDecodableInitializer(
                selectionSet,
                hasFields: !typePlan.fields.isEmpty,
                hasNonnilTypenameField: hasNonnilTypenameField,
                configuration: configuration,
                typeScope: selectionTypeScope
            )
        }
    }

    private mutating func addNestedStruct(
        responseKey: String,
        for fieldType: ResolvedFieldType,
        immutable: Bool,
        isPublic: Bool,
        conformances: OrderedSet<String>,
        configuration: Configuration,
        typeScope: SwiftTypeScope
    ) throws {
        switch fieldType {
        case .scalar: break
        case .map(let map):
            var nestedStruct = SwiftStructBuilder(
                description: nil,
                isPublic: isPublic,
                name: SwiftTypeIdentifier(capitalizing: responseKey).source,
                conformances: conformances.elements,
                typeScope: typeScope
            )
            do {
                try nestedStruct.addSelectionSet(
                    map,
                    immutable: immutable,
                    isPublic: isPublic,
                    conformances: conformances,
                    configuration: configuration,
                    typeScope: typeScope
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
                configuration: configuration,
                typeScope: typeScope
            )
        case .list(let innerType):
            try addNestedStruct(
                responseKey: responseKey,
                for: innerType,
                immutable: immutable,
                isPublic: isPublic,
                conformances: conformances,
                configuration: configuration,
                typeScope: typeScope
            )
        }
    }

    private mutating func addDecodableInitializer(
        _ selectionSet: ResolvedSelectionSet,
        hasFields: Bool,
        hasNonnilTypenameField: Bool,
        configuration: Configuration,
        typeScope: SwiftTypeScope
    ) throws {
        var initializerBody: [String] = []
        if hasFields {
            initializerBody.append(
                "let container = try decoder.container(keyedBy: \(SwiftTypeIdentifier.codingKeys.source).self)"
            )
        }
        var codingKeysEnum = hasFields ? SwiftEnumBuilder(
            description: nil,
            isPublic: false,
            name: SwiftTypeIdentifier.codingKeys.source,
            conformances: ["CodingKey"],
            typeScope: typeScope
        ) : nil
        for (responseKey, selection) in selectionSet {
            switch selection {
            case .field(let field, let conditional):
                var assignment = "\(identifier(responseKey)) = "
                assignment.append("try container.")
                let typename: String
                if conditional {
                    assignment.append("decodeIfPresent(")
                    typename = field.asNonOptional().sourceTypeName(
                        responseKey: responseKey,
                        typeScope: typeScope
                    ).formatted()
                } else {
                    assignment.append("decode(")
                    typename = field.sourceTypeName(
                        responseKey: responseKey,
                        typeScope: typeScope
                    ).formatted()
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
                let fragmentTypeName = SwiftTypeIdentifier(capitalizing: fragmentSpreadName).source
                var assignment = "\(identifier(responseKey)) = "
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
        addInitializer(
            arguments: [
                "from decoder: \(typeScope.reference(.init(.swift, "Decoder")))",
            ],
            body: initializerBody,
            isThrowing: true
        )
    }
}
