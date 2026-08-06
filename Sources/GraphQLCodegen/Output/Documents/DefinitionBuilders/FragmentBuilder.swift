import OrderedCollections

struct FragmentBuilder {
    let configuration: Configuration
    let document: Document
    let resolvedFragment: ResolvedFragment
    let resolvedDocuments: ResolvedDocuments

    private var fragment: Document.Fragment {
        resolvedFragment.fragment
    }

    private var isFulfilled: Bool {
        resolvedDocuments.fulfilledFragments.contains(fragment.ast.name.value)
    }

    private var isPublic: Bool {
        switch configuration.output.documents.accessLevel {
        case .internal: false
        case .public: true
        }
    }

    func buildable() throws -> SwiftTypeBuildable {
        var fragmentStruct = SwiftStructBuilder(
            description: nil,
            isPublic: isPublic,
            name: fragment.ast.name.value.capitalizedFirst,
            conformances: isFulfilled ? configuration.output.documents.fragments.conformances : []
        )
        if isFulfilled {
            try addSelectionSet(to: &fragmentStruct)
        }
        return fragmentStruct
    }

    private func addSelectionSet(to fragmentStruct: inout SwiftStructBuilder) throws {
        do {
            try fragmentStruct.addSelectionSet(
                resolvedFragment.resolvedSelectionSet,
                immutable: configuration.output.documents.fragments.immutable,
                isPublic: isPublic,
                conformances: OrderedSet(configuration.output.documents.fragments.conformances),
                configuration: configuration
            )
        } catch {
            switch error as? SelectionSetError {
            case .fragmentSpreadNeedsTypename(let fragmentSpread):
                throw Codegen.Error(description: """
                \(document.url)
                '__typename' needed on fragment '\(fragment.ast.name.value)'.
                In order to resolve the fragment spread '...\(fragmentSpread)', '__typename' is needed at the top level.
                Codegen never modifies your GraphQL documents, so please add '__typename' for this case.
                """)
            case .selectionSetNeedsTypename(let field, let fragmentSpread):
                throw Codegen.Error(description: """
                \(document.url)
                '__typename' needed in selection set under the '\(field)' field.
                In order to resolve the fragment spread '...\(fragmentSpread)', '__typename' is needed at the same level.
                Codegen never modifies your GraphQL documents, so please add '__typename' for this case.
                """)
            case .none: throw error
            }
        }
    }
}
