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
        configuration: Configuration
    ) throws {
        let typePlan = SelectionSetTypePlan(selectionSet: selectionSet, conformances: conformances)
        reservePropertyNames(selectionSet.map { responseKey, _ in responseKey })

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
                        type: conditionalField.sourceTypeName(responseKey: responseKey).formatted(),
                        initialized: configuration.output.documents.memberwiseInitializer ?
                            .direct(defaultValue: nil) : nil
                    )
                )
            case .fragmentSpread(let fragmentSpreadName, let condition):
                addProperty(
                    description: nil,
                    deprecation: nil,
                    isPublic: isPublic,
                    isStatic: false,
                    immutable: immutable,
                    name: responseKey,
                    value: .unassigned(
                        type: SwiftTypeIdentifier(capitalizing: fragmentSpreadName).source +
                            (condition != nil ? "?" : ""),
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
                    configuration: configuration
                )
            }
        }
        let includesDecodable = conformances.contains { conformance in
            SwiftConformanceName(source: conformance).includesDecodable
        }
        if typePlan.hasFragments || ancestorTypenameFragment(in: selectionSet) != nil, includesDecodable {
            try addDecodableInitializer(
                selectionSet,
                hasFields: !typePlan.fields.isEmpty,
                hasNonnilTypenameField: hasNonnilTypenameField,
                configuration: configuration
            )
        }
    }

    private mutating func addNestedStruct(
        responseKey: String,
        for fieldType: ResolvedFieldType,
        immutable: Bool,
        isPublic: Bool,
        conformances: OrderedSet<String>,
        configuration: Configuration
    ) throws {
        switch fieldType {
        case .scalar: break
        case .map(let map):
            var nestedStruct = SwiftStructBuilder(
                description: nil,
                isPublic: isPublic,
                name: SwiftTypeIdentifier(capitalizing: responseKey).source,
                conformances: conformances.elements
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
                case .none, .selectionSetNeedsTypename: throw error
                }
            }
            addNestedType(nestedStruct)
        case .list(let innerType), .optional(let innerType):
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

    private mutating func addDecodableInitializer(
        _ selectionSet: ResolvedSelectionSet,
        hasFields: Bool,
        hasNonnilTypenameField: Bool,
        configuration: Configuration
    ) throws {
        let currentTypenameFragment = ancestorTypenameFragment(in: selectionSet, levelsUp: 0)
        if let currentTypenameFragment, !hasNonnilTypenameField {
            throw SelectionSetError.fragmentSpreadNeedsTypename(fragmentSpread: currentTypenameFragment)
        }

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
            conformances: ["CodingKey"]
        ) : nil
        var decodingSelections = Array(selectionSet)
        if currentTypenameFragment != nil,
           let typenameIndex = decodingSelections.firstIndex(where: { $0.key == "__typename" }) {
            let typenameSelection = decodingSelections.remove(at: typenameIndex)
            decodingSelections.insert(typenameSelection, at: 0)
        }
        for (responseKey, selection) in decodingSelections {
            switch selection {
            case .field(let field, let conditional):
                var assignment = "\(storageName(forProperty: responseKey)) = "
                var decode = "try container."
                let typename: String
                if conditional {
                    decode.append("decodeIfPresent(")
                    typename = field.asNonOptional().sourceTypeName(responseKey: responseKey).formatted()
                } else {
                    decode.append("decode(")
                    typename = field.sourceTypeName(responseKey: responseKey).formatted()
                }
                decode.append("\(typename).self, forKey: .\(responseKey))")
                if let nestedSelectionSet = field.type.unwrappedMap(),
                   ancestorTypenameFragment(in: nestedSelectionSet) != nil {
                    let parentTypename = currentTypenameFragment == nil ? "nil" : "__typename"
                    assignment.append(
                        "try GraphQLResponseDecodingContext.withAncestorTypename(\(parentTypename)) { \(decode) }"
                    )
                } else {
                    assignment.append(decode)
                }
                codingKeysEnum?.addCase(description: nil, deprecation: nil, name: responseKey)
                initializerBody.append(assignment)
            case .fragmentSpread: break
            }
        }
        if selectionSet.contains(where: { _, selection in
            guard case .fragmentSpread(_, let condition) = selection else { return false }
            return condition?.dependsOnDirectiveVariables == true
        }) {
            let indentation = configuration.output.indentation.string
            initializerBody.append(contentsOf: [
                "guard let fragmentDecodingContext = " +
                    "decoder.userInfo[.graphQLResponseDecodingContext] as? GraphQLResponseDecodingContext else {",
                "\(indentation)throw DecodingError.dataCorrupted(DecodingError.Context(",
                "\(indentation)\(indentation)codingPath: decoder.codingPath,",
                "\(indentation)\(indentation)debugDescription: \"Conditional fragments require operation directive variables.\"",
                "\(indentation)))",
                "}",
            ])
        }
        for (responseKey, selection) in selectionSet {
            switch selection {
            case .field: break
            case .fragmentSpread(let fragmentSpreadName, let condition):
                let fragmentTypeName = SwiftTypeIdentifier(capitalizing: fragmentSpreadName).source
                var assignment = "\(identifier(responseKey)) = "
                if let condition {
                    if condition.requiresTypename, !hasNonnilTypenameField {
                        throw SelectionSetError.fragmentSpreadNeedsTypename(fragmentSpread: fragmentSpreadName)
                    }
                    assignment.append(fragmentConditionSource(condition) + " ? ")
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
                "from decoder: Decoder",
            ],
            body: initializerBody,
            isThrowing: true
        )
    }

    private func fragmentConditionSource(_ condition: FragmentFulfillmentCondition) -> String {
        switch condition {
        case .literal(let value): return String(value)
        case .typename(let typename):
            return "__typename == \(SwiftSource(value: typename).singleLineStringLiteral)"
        case .ancestorTypename(let typename, let levelsUp):
            return "GraphQLResponseDecodingContext.ancestorTypename(levelsUp: \(levelsUp)) == " +
                SwiftSource(value: typename).singleLineStringLiteral
        case .include(let variable):
            return "fragmentDecodingContext.directiveVariables[\(SwiftSource(value: variable).singleLineStringLiteral)] == true"
        case .skip(let variable):
            return "fragmentDecodingContext.directiveVariables[\(SwiftSource(value: variable).singleLineStringLiteral)] != true"
        case .and(let conditions):
            return "(" + conditions.map(fragmentConditionSource).joined(separator: " && ") + ")"
        case .or(let conditions):
            return "(" + conditions.map(fragmentConditionSource).joined(separator: " || ") + ")"
        }
    }

    private func ancestorTypenameFragment(
        in selectionSet: ResolvedSelectionSet,
        levelsUp: Int? = nil
    ) -> String? {
        for selection in selectionSet.values {
            switch selection {
            case .fragmentSpread(let name, let condition):
                if condition?.dependsOnAncestorTypename(levelsUp: levelsUp) == true { return name }
            case .field(let field, _):
                guard let nestedSelectionSet = field.type.unwrappedMap() else { continue }
                let nextLevelsUp = levelsUp.map { $0 + 1 }
                if let name = ancestorTypenameFragment(in: nestedSelectionSet, levelsUp: nextLevelsUp) {
                    return name
                }
            }
        }
        return nil
    }
}
