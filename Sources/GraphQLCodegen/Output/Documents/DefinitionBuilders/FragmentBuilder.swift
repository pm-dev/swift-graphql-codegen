struct FragmentBuilder {
    let configuration: Configuration
    let document: Document
    let resolvedFragment: ResolvedFragment
    let resolvedDocuments: ResolvedDocuments

    private var fragmentStruct = SwiftStructBuilder()

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

    init(
        configuration: Configuration,
        document: Document,
        resolvedFragment: ResolvedFragment,
        resolvedDocuments: ResolvedDocuments
    ) {
        self.configuration = configuration
        self.document = document
        self.resolvedFragment = resolvedFragment
        self.resolvedDocuments = resolvedDocuments
    }

    mutating func buildable() throws -> SwiftTypeBuildable {
        startFragmentStruct()
        addSourceProperty()
        if isFulfilled {
            try addSelectionSet()
        }
        return fragmentStruct
    }

    private mutating func addSelectionSet() throws {
        do {
            try fragmentStruct.addSelectionSet(
                resolvedFragment.resolvedSelectionSet,
                immutable: configuration.output.documents.fragments.immutable,
                isPublic: isPublic,
                conformances: configuration.output.documents.fragments.conformances,
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

    private mutating func startFragmentStruct() {
        fragmentStruct.start(
            description: nil,
            isPublic: isPublic,
            structName: fragment.ast.name.value.capitalizedFirst,
            conformances: isFulfilled ? configuration.output.documents.fragments.conformances : []
        )
    }

    private mutating func addSourceProperty() {
        switch configuration.output.documents.operations.persistedOperations {
        case .registered: break
        case .automatic, .none:
            fragmentStruct.addProperty(
                description: nil,
                deprecation: nil,
                isPublic: isPublic,
                isStatic: true,
                immutable: true,
                name: "source",
                value: .assigned("\"\"\"\n\(fragment.sourceText)\n\"\"\"", type: nil)
            )
        }
    }
}
