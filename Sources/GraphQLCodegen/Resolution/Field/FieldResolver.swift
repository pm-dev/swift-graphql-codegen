import OrderedCollections

struct FieldResolver {
    let fieldSelection: AST.Field
    let fieldSchema: __Schema.__Field
    let schema: Schema
    let documents: Documents

    func resolve() throws -> ResolvedField {
        try ResolvedField(
            type: resolveFieldType(schema.fieldType(fieldSchema)),
            deprecation: fieldSchema.isDeprecated ? Deprecation(reason: fieldSchema.deprecationReason) : nil,
            description: fieldSchema.description
        )
    }

    private func resolveFieldType(
        _ fieldType: Schema.Field
    ) throws -> ResolvedFieldType {
        switch fieldType {
        case .SCALAR(let scalarType):
            return .optional(innerType: .scalar(typeName: scalarType.ast.swiftName, isEnum: false))
        case .OBJECT(let objectType):
            guard let selectionSet = fieldSelection.selectionSet else {
                throw missingSelectionSetError()
            }
            return .optional(
                innerType: .map(
                    try SelectionSetResolver(
                        onType: .OBJECT(objectType),
                        selectionSet: selectionSet,
                        schema: schema,
                        documents: documents
                    ).resolve()
                )
            )
        case .INTERFACE(let interfaceType):
            guard let selectionSet = fieldSelection.selectionSet else {
                throw missingSelectionSetError()
            }
            return .optional(
                innerType: .map(
                    try SelectionSetResolver(
                        onType: .INTERFACE(interfaceType),
                        selectionSet: selectionSet,
                        schema: schema,
                        documents: documents
                    ).resolve()
                )
            )
        case .UNION(let unionType):
            guard let selectionSet = fieldSelection.selectionSet else {
                throw missingSelectionSetError()
            }
            return .optional(
                innerType: .map(
                    try SelectionSetResolver(
                        onType: .UNION(unionType),
                        selectionSet: selectionSet,
                        schema: schema,
                        documents: documents
                    ).resolve()
                )
            )
        case .ENUM(let `enum`):
            return .optional(innerType: .scalar(typeName: `enum`.ast.name, isEnum: true))
        case .LIST(let innerType):
            let resolved = try resolveFieldType(innerType)
            return .optional(innerType: .list(innerType: resolved))
        case .NON_NULL(let innerType):
            let resolved = try resolveFieldType(innerType)
            switch resolved {
            case .optional(let innerType): return innerType
            case .list, .map, .scalar: return resolved // already non-null
            }
        }
    }

    private func missingSelectionSetError() -> Codegen.Error {
        Codegen.Error(description: """
        Selected field \(fieldSelection.responseKey) which requires a selection set.

        Note: Turning on validation can help find other similar errors
        """)
    }
}
