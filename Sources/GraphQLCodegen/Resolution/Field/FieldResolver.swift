import OrderedCollections

struct FieldResolver {
    let fieldSelection: GraphQLAST.Field
    let fieldSchema: __Schema.__Field
    let schema: Schema
    let documents: Documents

    func resolve() throws -> ResolvedField {
        ResolvedField(
            type: try resolveFieldType(schema.fieldType(fieldSchema)),
            deprecation: fieldSchema.isDeprecated ? Deprecation(reason: fieldSchema.deprecationReason) : nil,
            description: fieldSchema.description
        )
    }

    private func resolveFieldType(
        _ fieldType: Schema.Field
    ) throws -> ResolvedFieldType {
        switch fieldType {
        case .nullable(let value): .optional(innerType: try resolveFieldValue(value))
        case .nonNull(let value): try resolveFieldValue(value)
        }
    }

    private func resolveFieldValue(
        _ value: Schema.Field.Value
    ) throws -> ResolvedFieldType {
        switch value {
        case .SCALAR(let scalarType):
            return .scalar(typeName: scalarType.ast.swiftName, isEnum: false)
        case .OBJECT(let objectType):
            guard let selectionSet = fieldSelection.selectionSet else {
                throw missingSelectionSetError()
            }
            return .map(
                try SelectionSetResolver(
                    onType: .OBJECT(objectType),
                    selectionSet: selectionSet,
                    schema: schema,
                    documents: documents
                ).resolve()
            )
        case .INTERFACE(let interfaceType):
            guard let selectionSet = fieldSelection.selectionSet else {
                throw missingSelectionSetError()
            }
            return .map(
                try SelectionSetResolver(
                    onType: .INTERFACE(interfaceType),
                    selectionSet: selectionSet,
                    schema: schema,
                    documents: documents
                ).resolve()
            )
        case .UNION(let unionType):
            guard let selectionSet = fieldSelection.selectionSet else {
                throw missingSelectionSetError()
            }
            return .map(
                try SelectionSetResolver(
                    onType: .UNION(unionType),
                    selectionSet: selectionSet,
                    schema: schema,
                    documents: documents
                ).resolve()
            )
        case .ENUM(let `enum`):
            return .scalar(typeName: `enum`.ast.name, isEnum: true)
        case .LIST(let innerType):
            return .list(innerType: try resolveFieldType(innerType))
        }
    }

    private func missingSelectionSetError() -> Codegen.Error {
        Codegen.Error(description: """
        Selected field \(fieldSelection.responseKey) which requires a selection set.

        Note: Turning on validation can help find other similar errors
        """)
    }
}
