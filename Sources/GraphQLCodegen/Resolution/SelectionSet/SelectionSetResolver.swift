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
    /// https://spec.graphql.org/October2021/#sec-Field-Collection
    func resolve() throws -> ResolvedSelectionSet {
        try collect(
            selectionSet: selectionSet,
            onType: onType,
            typeCondition: .always,
            inOptionalDirective: false
        )
    }

    private func collect(
        selectionSet: GraphQLAST.SelectionSet,
        onType: Schema.SelectionSet,
        typeCondition: TypeCondition,
        inOptionalDirective: Bool
    ) throws -> ResolvedSelectionSet {
        var resolvedSelectionSet = ResolvedSelectionSet()
        for selection in selectionSet.selections {
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
                        documents: documents
                    ).resolve()
                let conditional = typeCondition.isConditional ||
                    inOptionalDirective ||
                    selection.hasOptionalDirective
                try resolvedSelectionSet.addSelection(
                    .field(resolvedField, conditional: conditional),
                    responseKey: field.responseKey
                )
            case .fragmentSpread(let fragmentSpread):
                let fragmentName = fragmentSpread.name.value
                if fragmentName == "typename" {
                    throw Codegen.Error(description: """
                    "typename" is not allowed as a fragment spread name.
                    """)
                }
                if inOptionalDirective || selection.hasOptionalDirective {
                    throw Codegen.Error(description: """
                    'skip' or 'include' directives are not currently supported on fragment spreads.
                    It's not possible to determine whether this fragment spread is fulfilled.
                    During decoding, we don't have access to the variable which determines whether the
                    fragment spread is fulfilled.
                    Fragment name: \(fragmentName)
                    """)
                }
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
                        .fragmentSpread(fragmentName, checkTypenames: nil),
                        responseKey: "__" + fragmentName
                    )
                case .typename(let typename):
                    try resolvedSelectionSet.addSelection(
                        .fragmentSpread(fragmentName, checkTypenames: [typename]),
                        responseKey: "__" + fragmentName
                    )
                case .abstract:
                    // Because we can't verify whether these fragments are fulfilled, we'll
                    // roll their fields up to the response type, rather than using the fragment type.
                    // https://github.com/graphql/graphql-spec/pull/879
                    let fragmentGroupedSelections = try collect(
                        selectionSet: fragment.ast.selectionSet,
                        onType: fragmentType,
                        typeCondition: fragmentTypeCondition,
                        inOptionalDirective: inOptionalDirective || selection.hasOptionalDirective
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
                    inOptionalDirective: inOptionalDirective || selection.hasOptionalDirective
                )
                try resolvedSelectionSet.merge(fragmentGroupedSelections) { try $0.merging(with: $1) }
            }
        }
        return resolvedSelectionSet
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
