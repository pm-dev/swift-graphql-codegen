import OrderedCollections

struct DocumentsResolver {
    private struct InputObjectDependency: Hashable {
        let fieldName: String
        let inputObjectName: String
        let nestedInputObjectName: String
    }

    private struct Usage {
        var fulfilledFragments: Set<String> = []
        var hasMutation = false
        var hasSubscription = false
        var usedTypes: Set<String> = []
    }

    let schema: Schema
    let documents: Documents

    func resolve() throws -> ResolvedDocuments {
        let usedFragments = try usedFragments()
        let resolvedFragments = try resolveFragments(usedFragments)
        let resolvedDocuments = try resolveDocuments(documents)
        let usage = try usage(in: resolvedDocuments, resolvedFragments: resolvedFragments)
        return try ResolvedDocuments(
            documents: resolvedDocuments,
            fragmentLookup: resolvedFragments,
            fulfilledFragments: usage.fulfilledFragments,
            hasMutation: usage.hasMutation,
            hasSubscription: usage.hasSubscription,
            indirectOneOfInputObjectFields: indirectOneOfInputObjectFields(in: usage.usedTypes),
            requiresIndirectNullable: requiresIndirectNullable(in: usage.usedTypes),
            usedTypes: usage.usedTypes
        )
    }

    private func usedFragments() throws -> [String: Document.Fragment] {
        var selectionSets: [GraphQLAST.SelectionSet] = []
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
                        let fragment = try documents.fragment(fragmentSpreadName)
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
    ) throws -> [String: ResolvedFragment] {
        var resolvedFragments: [String: ResolvedFragment] = [:]
        for (name, fragment) in usedFragments.sorted(by: { $0.key < $1.key }) {
            let selectionSet = try SelectionSetResolver(
                onType: schema.fragmentType(fragment.ast),
                selectionSet: fragment.ast.selectionSet,
                schema: schema,
                documents: documents
            ).resolve()
            resolvedFragments[name] = ResolvedFragment(
                fragment: fragment,
                resolvedSelectionSet: selectionSet
            )
        }
        return resolvedFragments
    }

    private func resolveDocuments(_ documents: Documents) throws -> [ResolvedDocument] {
        var resolvedDocuments: [ResolvedDocument] = []
        for document in documents.documents {
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
            resolvedDocuments.append(
                ResolvedDocument(document: document, resolvedDefinitions: resolvedDefinitions)
            )
        }
        return resolvedDocuments
    }

    private func usage(
        in resolvedDocuments: [ResolvedDocument],
        resolvedFragments: [String: ResolvedFragment]
    ) throws -> Usage {
        var usage = Usage()
        var selectionSets: [ResolvedSelectionSet] = []
        for resolvedDocument in resolvedDocuments {
            for definition in resolvedDocument.resolvedDefinitions {
                switch definition {
                case .operation(let resolvedOperation):
                    selectionSets.append(resolvedOperation.resolvedSelectionSet)
                    for variableDefinition in resolvedOperation.operation.ast.variableDefinitions ?? [] {
                        try addUsedInputTypes(variableDefinition, to: &usage.usedTypes)
                    }
                    switch resolvedOperation.operation.ast.operation {
                    case .mutation: usage.hasMutation = true
                    case .query: break
                    case .subscription: usage.hasSubscription = true
                    }
                case .fragment: break
                }
            }
        }

        while let selectionSet = selectionSets.popLast() {
            for selection in selectionSet.values {
                switch selection {
                case .fragmentSpread(let name, _):
                    guard usage.fulfilledFragments.insert(name).inserted else { continue }
                    let resolvedFragment = resolvedFragments[name]!
                    selectionSets.append(resolvedFragment.resolvedSelectionSet)
                case .field(let field, _):
                    var fieldType: ResolvedFieldType? = field.type
                    while let type = fieldType {
                        switch type {
                        case .scalar(let name, _):
                            usage.usedTypes.insert(name)
                            fieldType = nil
                        case .map(let nestedSelectionSet):
                            selectionSets.append(nestedSelectionSet)
                            fieldType = nil
                        case .list(let innerType), .optional(let innerType):
                            fieldType = innerType
                        }
                    }
                }
            }
        }

        return usage
    }

    private func addUsedInputTypes(
        _ variableDefinition: GraphQLAST.VariableDefinition,
        to usedTypes: inout Set<String>
    ) throws {
        var inputTypes = try [schema.inputType(variableDefinition)]
        while let inputType = inputTypes.popLast() {
            switch inputType.value {
            case .SCALAR(let scalar): usedTypes.insert(scalar.ast.name)
            case .ENUM(let `enum`): usedTypes.insert(`enum`.ast.name)
            case .INPUT_OBJECT(let inputObject):
                guard usedTypes.insert(inputObject.ast.name).inserted else { continue }
                try inputTypes.append(contentsOf: inputObject.ast.inputFields.map { try schema.inputType($0) })
            case .LIST(let innerType): inputTypes.append(innerType)
            }
        }
    }

    private func requiresIndirectNullable(in usedTypes: Set<String>) throws -> Bool {
        try !recursiveInputObjectDependencies(in: usedTypes) { inputObject in
            try inputObject.ast.inputFields.compactMap { field in
                guard case .INPUT_OBJECT(let nestedInputObject) = try schema.inputType(field).value else {
                    return nil
                }
                return InputObjectDependency(
                    fieldName: field.name,
                    inputObjectName: inputObject.ast.name,
                    nestedInputObjectName: nestedInputObject.ast.name
                )
            }
        }.isEmpty
    }

    private func indirectOneOfInputObjectFields(in usedTypes: Set<String>) throws -> [String: Set<String>] {
        let recursiveDependencies = try recursiveInputObjectDependencies(in: usedTypes) { inputObject in
            try directlyStoredInputObjectDependencies(in: inputObject)
        }
        return recursiveDependencies.reduce(into: [:]) { result, dependency in
            guard schema.typeCache.inputObjects[dependency.inputObjectName]?.ast.isOneOf == true else { return }
            result[dependency.inputObjectName, default: []].insert(dependency.fieldName)
        }
    }

    private func directlyStoredInputObjectDependencies(
        in inputObject: Schema.InputObject
    ) throws -> [InputObjectDependency] {
        try inputObject.ast.inputFields.compactMap { field in
            let type = try schema.inputType(field)
            let storesWithoutNullableWrapper =
                switch type {
                case .nullable: inputObject.ast.isOneOf
                case .nonNull: true
                }
            guard storesWithoutNullableWrapper,
                  case .INPUT_OBJECT(let nestedInputObject) = type.value
            else {
                return nil
            }
            return InputObjectDependency(
                fieldName: field.name,
                inputObjectName: inputObject.ast.name,
                nestedInputObjectName: nestedInputObject.ast.name
            )
        }
    }

    private func recursiveInputObjectDependencies(
        in usedTypes: Set<String>,
        dependencies: (Schema.InputObject) throws -> [InputObjectDependency]
    ) throws -> Set<InputObjectDependency> {
        var dependenciesByInputObject: [String: [InputObjectDependency]] = [:]
        for name in usedTypes.sorted() {
            guard let inputObject = schema.typeCache.inputObjects[name] else { continue }
            dependenciesByInputObject[name] = try dependencies(inputObject)
        }

        func canReach(_ destination: String, from source: String, visited: inout Set<String>) -> Bool {
            if source == destination {
                return true
            }
            guard visited.insert(source).inserted else { return false }
            return dependenciesByInputObject[source, default: []].contains { dependency in
                canReach(destination, from: dependency.nestedInputObjectName, visited: &visited)
            }
        }

        return Set(dependenciesByInputObject.values.joined().filter { dependency in
            var visited: Set<String> = []
            return canReach(
                dependency.inputObjectName,
                from: dependency.nestedInputObjectName,
                visited: &visited
            )
        })
    }
}
