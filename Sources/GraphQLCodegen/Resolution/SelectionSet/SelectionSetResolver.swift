import OrderedCollections

struct SelectionSetResolver {
    private enum TypeCondition {
        case abstract
        case always
        case typename(String)

        var isConditional: Bool {
            switch self {
            case .abstract, .typename: true
            case .always: false
            }
        }
    }

    let onType: Schema.SelectionSet
    let selectionSet: GraphQLAST.SelectionSet
    let schema: Schema
    let documents: Documents

    /// Ensure field ordering matches response ordering by following a similar algorithm to:
    /// https://spec.graphql.org/September2025/#sec-Field-Collection
    func resolve(inheritedFragmentCondition: FragmentFulfillmentCondition? = nil) throws -> ResolvedSelectionSet {
        try collect(
            selectionSet: selectionSet,
            onType: onType,
            typeCondition: .always,
            directiveCondition: nil,
            inheritedFragmentCondition: inheritedFragmentCondition
        )
    }

    private func collect(
        selectionSet: GraphQLAST.SelectionSet,
        onType: Schema.SelectionSet,
        typeCondition: TypeCondition,
        directiveCondition: FragmentFulfillmentCondition?,
        inheritedFragmentCondition: FragmentFulfillmentCondition?
    ) throws -> ResolvedSelectionSet {
        var resolvedSelectionSet = ResolvedSelectionSet()
        for selection in selectionSet.selections {
            let selectionCondition = self.directiveCondition(for: selection)
            let effectiveFragmentCondition = FragmentFulfillmentCondition.all(
                [inheritedFragmentCondition, directiveCondition, selectionCondition].compactMap { $0 }
            )
            switch selection {
            case .field(let field):
                var resolvedField = field.name.value == "__typename" ? ResolvedField(
                    type: .scalar(typeName: "String", isEnum: false),
                    deprecation: nil,
                    description: nil
                ) : try FieldResolver(
                    fieldSelection: field,
                    fieldSchema: onType.field(field),
                    schema: schema,
                    schemaCoordinate: .member(type: onType.name, member: field.name.value),
                    documents: documents,
                    inheritedFragmentCondition: effectiveFragmentCondition
                ).resolve()
                if case .typename(let typename) = typeCondition,
                   resolvedField.type.unwrappedMap() != nil {
                    resolvedField = addingAncestorTypename(typename, to: resolvedField)
                }
                let conditional = typeCondition.isConditional ||
                    directiveCondition != nil ||
                    selection.hasOptionalDirective
                try resolvedSelectionSet.addSelection(
                    .field(resolvedField, conditional: conditional),
                    responseKey: field.responseKey
                )
            case .fragmentSpread(let fragmentSpread):
                let fragmentName = fragmentSpread.name.value
                let fragmentResponseKey = fragmentName == "typename" ? "__typenameFragment" : "__" + fragmentName
                let fragment = try documents.fragment(fragmentName)
                let fragmentType = try schema.fragmentType(fragment.ast)
                let fragmentTypeCondition = nestedTypeCondition(
                    typeCondition,
                    fragmentType: fragmentType,
                    onType: onType
                )
                switch fragmentTypeCondition {
                case .always:
                    try resolvedSelectionSet.addSelection(
                        .fragmentSpread(fragmentName, condition: effectiveFragmentCondition),
                        responseKey: fragmentResponseKey
                    )
                case .typename(let typename):
                    try resolvedSelectionSet.addSelection(
                        .fragmentSpread(
                            fragmentName,
                            condition: FragmentFulfillmentCondition.all(
                                [.typename(typename), effectiveFragmentCondition].compactMap { $0 }
                            )
                        ),
                        responseKey: fragmentResponseKey
                    )
                case .abstract:
                    // Because we can't verify whether these fragments are fulfilled, we'll
                    // roll their fields up to the response type, rather than using the fragment type.
                    // https://github.com/graphql/graphql-spec/pull/879
                    let fragmentGroupedSelections = try collect(
                        selectionSet: fragment.ast.selectionSet,
                        onType: fragmentType,
                        typeCondition: fragmentTypeCondition,
                        directiveCondition: effectiveFragmentCondition,
                        inheritedFragmentCondition: nil
                    )
                    try resolvedSelectionSet.merge(fragmentGroupedSelections) { try $0.merging(with: $1) }
                }
            case .inlineFragment(let inlineFragment):
                let fragmentType = try schema.fragmentType(inlineFragment) ?? onType
                let fragmentGroupedSelections = try collect(
                    selectionSet: inlineFragment.selectionSet,
                    onType: fragmentType,
                    typeCondition: nestedTypeCondition(
                        typeCondition,
                        fragmentType: fragmentType,
                        onType: onType
                    ),
                    directiveCondition: FragmentFulfillmentCondition.all(
                        [directiveCondition, selectionCondition].compactMap { $0 }
                    ),
                    inheritedFragmentCondition: inheritedFragmentCondition
                )
                try resolvedSelectionSet.merge(fragmentGroupedSelections) { try $0.merging(with: $1) }
            }
        }
        return resolvedSelectionSet
    }

    private func directiveCondition(for selection: GraphQLAST.Selection) -> FragmentFulfillmentCondition? {
        let conditions = selection.directives.compactMap { directive -> FragmentFulfillmentCondition? in
            let name = directive.name.value
            guard name == "include" || name == "skip",
                  let argument = directive.arguments?.first(where: { $0.name.value == "if" }) else {
                return nil
            }
            switch argument.value {
            case .boolean(let boolean):
                return .literal(name == "include" ? boolean.value : !boolean.value)
            case .variable(let variable):
                return name == "include" ? .include(variable.name.value) : .skip(variable.name.value)
            default:
                return nil
            }
        }
        return FragmentFulfillmentCondition.all(conditions)
    }

    private func addingAncestorTypename(
        _ typename: String,
        to field: ResolvedField,
        levelsUp: Int = 1
    ) -> ResolvedField {
        ResolvedField(
            type: addingAncestorTypename(typename, to: field.type, levelsUp: levelsUp),
            deprecation: field.deprecation,
            description: field.description
        )
    }

    private func addingAncestorTypename(
        _ typename: String,
        to fieldType: ResolvedFieldType,
        levelsUp: Int
    ) -> ResolvedFieldType {
        switch fieldType {
        case .scalar:
            return fieldType
        case .map(let selectionSet):
            var conditionedSelectionSet = selectionSet
            for (responseKey, selection) in selectionSet {
                switch selection {
                case .fragmentSpread(let name, let condition):
                    guard condition?.dependsOnDirectiveVariables == true ||
                        fragmentContainsDirectiveConditionalSpread(name) else { continue }
                    conditionedSelectionSet[responseKey] = .fragmentSpread(
                        name,
                        condition: FragmentFulfillmentCondition.all(
                            [.ancestorTypename(typename, levelsUp: levelsUp), condition].compactMap { $0 }
                        )
                    )
                case .field(let field, let conditional):
                    guard field.type.unwrappedMap() != nil else { continue }
                    conditionedSelectionSet[responseKey] = .field(
                        addingAncestorTypename(typename, to: field, levelsUp: levelsUp + 1),
                        conditional: conditional
                    )
                }
            }
            return .map(conditionedSelectionSet)
        case .list(let innerType):
            return .list(innerType: addingAncestorTypename(typename, to: innerType, levelsUp: levelsUp))
        case .optional(let innerType):
            return .optional(innerType: addingAncestorTypename(typename, to: innerType, levelsUp: levelsUp))
        }
    }

    private func fragmentContainsDirectiveConditionalSpread(_ name: String) -> Bool {
        guard let fragment = documents.fragmentLookup[name] else { return false }
        var selectionSets = [(fragment.ast.selectionSet, false)]
        var visitedFragments: Set<String> = [name]
        while let (selectionSet, inheritedCondition) = selectionSets.popLast() {
            for selection in selectionSet.selections {
                let isConditional = inheritedCondition ||
                    directiveCondition(for: selection)?.dependsOnDirectiveVariables == true
                switch selection {
                case .field(let field):
                    if let nestedSelectionSet = field.selectionSet {
                        selectionSets.append((nestedSelectionSet, isConditional))
                    }
                case .fragmentSpread(let spread):
                    if isConditional { return true }
                    let fragmentName = spread.name.value
                    guard visitedFragments.insert(fragmentName).inserted,
                          let nestedFragment = documents.fragmentLookup[fragmentName] else { continue }
                    selectionSets.append((nestedFragment.ast.selectionSet, false))
                case .inlineFragment(let inlineFragment):
                    selectionSets.append((inlineFragment.selectionSet, isConditional))
                }
            }
        }
        return false
    }

    private func nestedTypeCondition(
        _ inherited: TypeCondition,
        fragmentType: Schema.SelectionSet,
        onType: Schema.SelectionSet
    ) -> TypeCondition {
        guard !schema.isFragment(fragmentType, alwaysFulfilledBy: onType) else {
            return inherited
        }
        return switch fragmentType {
        case .OBJECT(let object): .typename(object.ast.name)
        case .INTERFACE, .UNION: .abstract
        }
    }
}

extension ResolvedSelectionSet {
    fileprivate mutating func addSelection(_ selection: ResolvedSelection, responseKey: String) throws {
        if let existing = self[responseKey] {
            self[responseKey] = try existing.merging(with: selection)
        } else {
            self[responseKey] = selection
        }
    }
}
