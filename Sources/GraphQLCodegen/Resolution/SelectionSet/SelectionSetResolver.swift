import OrderedCollections

struct SelectionSetResolver {
    let onType: Schema.SelectionSet
    let selectionSet: AST.SelectionSet
    let schema: Schema
    let documents: Documents

    /// Ensure field ordering matches response ordering by following a similar algorithm to:
    /// https://spec.graphql.org/October2021/#sec-Field-Collection
    func resolve() throws -> ResolvedSelectionSet {
        try collect(
            selectionSet: selectionSet,
            onType: onType,
            inOptionalDirective: false
        )
    }

    private func collect(
        selectionSet: AST.SelectionSet,
        onType: Schema.SelectionSet,
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
                        documents: documents
                    ).resolve()
                let conditional = self.onType.name != onType.name ||
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
                if schema.isFragment(fragmentType, alwaysFulfilledBy: self.onType) {
                    try resolvedSelectionSet.addSelection(
                        .fragmentSpread(fragmentName, checkTypename: nil),
                        responseKey: "__" + fragmentName
                    )
                } else {
                    switch fragmentType {
                    case .OBJECT(let object):
                        try resolvedSelectionSet.addSelection(
                            .fragmentSpread(fragmentName, checkTypename: object.ast.name),
                            responseKey: "__" + fragmentName
                        )
                    case .INTERFACE, .UNION:
                        // Because we can't verify whether these fragments are fulfilled, we'll
                        // roll their fields up to the response type, rather than using the fragment type.
                        // https://github.com/graphql/graphql-spec/pull/879
                        let fragmentGroupedSelections = try collect(
                            selectionSet: fragment.ast.selectionSet,
                            onType: fragmentType,
                            inOptionalDirective: inOptionalDirective || selection.hasOptionalDirective
                        )
                        try resolvedSelectionSet.merge(fragmentGroupedSelections) { try $0.merging(with: $1) }
                    }
                }
            case .inlineFragment(let inlineFragment):
                let fragmentGroupedSelections = try collect(
                    selectionSet: inlineFragment.selectionSet,
                    onType: try schema.fragmentType(inlineFragment) ?? onType,
                    inOptionalDirective: inOptionalDirective || selection.hasOptionalDirective
                )
                try resolvedSelectionSet.merge(fragmentGroupedSelections) { try $0.merging(with: $1) }
            }
        }
        return resolvedSelectionSet
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
