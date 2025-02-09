import OrderedCollections

struct DocumentsResolver {
    let schema: Schema
    let documents: Documents

    func resolve() async throws -> ResolvedDocuments {
        let usedFragments = usedFragments()
        let resolvedFragments = try await resolveFragments(usedFragments)
        let resolvedDocuments = try await resolveDocuments(documents)
        let fulfilledFragments = fulfilledFragments(
            resolvedFragments: resolvedFragments,
            resolvedDocuments: resolvedDocuments
        )
        return ResolvedDocuments(
            previouslyGenerated: documents.previouslyGenerated,
            documents: resolvedDocuments,
            fragmentLookup: resolvedFragments,
            usedTypes: try usedTypes(in: resolvedDocuments, resolvedFragments: resolvedFragments),
            fulfilledFragments: fulfilledFragments,
            hasMutation: hasOperationType(.mutation),
            hasSubscription: hasOperationType(.subscription)
        )
    }

    private func usedFragments() -> [String: Document.Fragment] {
        var selectionSets: [AST.SelectionSet] = []
        for document in documents.documents {
            for definition in document.definitions {
                switch definition {
                case .operation(let operation): selectionSets.append(operation.ast.selectionSet)
                case .fragment: break
                }
            }
        }
        var usedFragments: [String: Document.Fragment] = [:]
        while let selectionSet = selectionSets.popLast() {
            for selection in selectionSet.selections {
                switch selection {
                case .field(let field):
                    if let selectionSet = field.selectionSet {
                        selectionSets.append(selectionSet)
                    }
                case .fragmentSpread(let fragmentSpread):
                    let fragmentSpreadName = fragmentSpread.name.value
                    if !usedFragments.keys.contains(fragmentSpreadName) {
                        let fragment = documents.fragmentLookup[fragmentSpreadName]!
                        usedFragments[fragmentSpreadName] = fragment
                        selectionSets.append(fragment.ast.selectionSet)
                    }
                case .inlineFragment(let inlineFragment):
                    selectionSets.append(inlineFragment.selectionSet)
                }
            }
        }
        return usedFragments
    }

    private func resolveFragments(
        _ usedFragments: [String: Document.Fragment]
    ) async throws -> [String: ResolvedFragment] {
        var resolvedFragments: [String: ResolvedFragment] = [:]
        try await withThrowingTaskGroup(of: (String, ResolvedFragment).self) { group in
            for (name, fragment) in usedFragments {
                group.addTask {
                    let selectionSet = try SelectionSetResolver(
                        onType: try schema.fragmentType(fragment.ast),
                        selectionSet: fragment.ast.selectionSet,
                        schema: schema,
                        documents: documents
                    ).resolve()
                    let resolvedFragment = ResolvedFragment(
                        fragment: fragment,
                        resolvedSelectionSet: selectionSet
                    )
                    return (name, resolvedFragment)
                }
            }
            for try await (name, resolvedFragment) in group {
                resolvedFragments[name] = resolvedFragment
            }
        }
        return resolvedFragments
    }

    private func resolveDocuments(_ documents: Documents) async throws -> [ResolvedDocument] {
        var resolvedDocuments: [ResolvedDocument] = []
        try await withThrowingTaskGroup(of: ResolvedDocument.self) { group in
            for document in documents.documents {
                group.addTask {
                    var resolvedDefinitions: [ResolvedDefinition] = []
                    for definition in document.definitions {
                        switch definition {
                        case .operation(let operation):
                            try resolvedDefinitions.append(
                                .operation(
                                    ResolvedOperation(
                                        operation: operation,
                                        resolvedSelectionSet: SelectionSetResolver(
                                            onType: .OBJECT(schema.operationType(operation)),
                                            selectionSet: operation.ast.selectionSet,
                                            schema: schema,
                                            documents: documents
                                        ).resolve()
                                    )
                                )
                            )
                        case .fragment(let name):
                            resolvedDefinitions.append(.fragment(name))
                        }
                    }
                    return ResolvedDocument(
                        document: document,
                        resolvedDefinitions: resolvedDefinitions
                    )
                }
            }
            for try await resolvedDocument in group {
                resolvedDocuments.append(resolvedDocument)
            }
        }
        return resolvedDocuments
    }

    private func fulfilledFragments(
        resolvedFragments: [String: ResolvedFragment],
        resolvedDocuments: [ResolvedDocument]
    ) -> Set<String> {
        var fulfilledFragments: Set<String> = []
        var selectionSets: [ResolvedSelectionSet] = resolvedFragments.values.map(\.resolvedSelectionSet)
        for resolvedDocument in resolvedDocuments {
            for definition in resolvedDocument.resolvedDefinitions {
                switch definition {
                case .operation(let resolvedOperation):
                    selectionSets.append(resolvedOperation.resolvedSelectionSet)
                case .fragment: break
                }
            }
        }
        while let selectionSet = selectionSets.popLast() {
            for selection in selectionSet.values {
                switch selection {
                case .field(let field, _):
                    if let selectionSet = field.type.unwrappedMap() {
                        selectionSets.append(selectionSet)
                    }
                case .fragmentSpread(let name, _):
                    let result = fulfilledFragments.insert(name)
                    if result.inserted {
                        let fragment = resolvedFragments[name]!
                        selectionSets.append(fragment.resolvedSelectionSet)
                    }
                }
            }
        }
        return fulfilledFragments
    }

    private func usedTypes(
        in resolvedDocuments: [ResolvedDocument],
        resolvedFragments: [String: ResolvedFragment]
    ) throws -> Set<String> {
        var seenFragmentSpreads: Set<String> = []
        var usedTypes: Set<String> = []
        for resolvedDocument in resolvedDocuments {
            for definition in resolvedDocument.resolvedDefinitions {
                switch definition {
                case .operation(let resolvedOperation):
                    usedTypes.formUnion(
                        usedScalarTypes(
                            resolvedOperation.resolvedSelectionSet,
                            resolvedFragments: resolvedFragments,
                            seenFragmentSpreads: &seenFragmentSpreads
                        )
                    )
                    for variable in resolvedOperation.operation.ast.variableDefinitions {
                        try usedTypes.formUnion(usedInputTypes(variable))
                    }
                case .fragment: break
                }
            }
        }
        return usedTypes
    }

    private func usedInputTypes(_ variableDefinition: AST.VariableDefinition) throws -> Set<String> {
        var usedTypes = Set<String>()
        let inputType = try schema.inputType(variableDefinition)
        var stack: [Schema.Input] = [inputType]
        while let type = stack.popLast() {
            switch type {
            case .SCALAR(let scalar): usedTypes.insert(scalar.ast.name)
            case .ENUM(let `enum`): usedTypes.insert(`enum`.ast.name)
            case .INPUT_OBJECT(let inputObject):
                usedTypes.insert(inputObject.ast.name)
                stack.append(contentsOf: try inputObject.ast.inputFields.map { try schema.inputType($0) })
            case .LIST(let innerType): stack.append(innerType)
            case .NON_NULL(let innerType): stack.append(innerType)
            }
        }
        return usedTypes
    }

    private func usedScalarTypes(
        _ selectionSet: ResolvedSelectionSet,
        resolvedFragments: [String: ResolvedFragment],
        seenFragmentSpreads: inout Set<String>
    ) -> Set<String> {
        var usedTypes: Set<String> = []
        var stack: [ResolvedSelectionSet] = [selectionSet]
        while let selectionSet = stack.popLast() {
            for selection in selectionSet.values {
                switch selection {
                case .fragmentSpread(let name, _):
                    let result = seenFragmentSpreads.insert(name)
                    if result.inserted {
                        let resolvedFragment = resolvedFragments[name]!
                        stack.append(resolvedFragment.resolvedSelectionSet)
                    }
                case .field(let field, _):
                    var currentType: ResolvedFieldType? = field.type
                    while let type = currentType {
                        switch type {
                        case .scalar(let typeName, _):
                            usedTypes.insert(typeName)
                            currentType = nil
                        case .map(let map):
                            stack.append(map)
                            currentType = nil
                        case .optional(let innerType):
                            currentType = innerType
                        case .list(let innerType):
                            currentType = innerType
                        }
                    }
                }
            }
        }
        return usedTypes
    }

    private func hasOperationType(_ type: AST.OperationType) -> Bool {
        for document in documents.documents {
            for definition in document.definitions {
                switch definition {
                case .operation(let operation):
                    if operation.ast.operation == type {
                        return true
                    }
                case .fragment: break
                }
            }
        }
        return false
    }
}
