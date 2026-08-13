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
                let resolvedField = field.name.value == "__typename" ? ResolvedField(
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
