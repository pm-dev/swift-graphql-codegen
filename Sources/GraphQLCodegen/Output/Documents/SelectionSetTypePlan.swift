struct SelectionSetTypePlan {
    struct Declaration {
        enum Origin {
            case codingKeys
            case responseKey(String)
        }

        let name: SwiftTypeIdentifier
        let origin: Origin
    }

    let declarations: [Declaration]
    let fields: [ResolvedField]
    let hasFragments: Bool

    init<S: Sequence>(
        selectionSet: ResolvedSelectionSet,
        conformances: S
    ) where S.Element == String {
        var declarations: [Declaration] = []
        var fields: [ResolvedField] = []
        var hasFragments = false
        for (responseKey, selection) in selectionSet {
            switch selection {
            case .field(let field, _):
                fields.append(field)
                if field.type.unwrappedMap() != nil {
                    declarations.append(
                        Declaration(
                            name: SwiftTypeIdentifier(capitalizing: responseKey),
                            origin: .responseKey(responseKey)
                        )
                    )
                }
            case .fragmentSpread:
                hasFragments = true
            }
        }
        if !fields.isEmpty, conformances.contains(where: { conformance in
            SwiftConformanceName(source: conformance).usesCodingKeys
        }) {
            declarations.append(Declaration(name: .codingKeys, origin: .codingKeys))
        }
        self.declarations = declarations
        self.fields = fields
        self.hasFragments = hasFragments
    }
}
