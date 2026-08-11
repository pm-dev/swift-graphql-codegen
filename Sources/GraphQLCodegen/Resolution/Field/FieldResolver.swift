import OrderedCollections

struct FieldResolver {
    let fieldSelection: GraphQLAST.Field
    let fieldSchema: __Schema.__Field
    let schema: Schema
    let schemaCoordinate: SchemaCoordinate
    let documents: Documents

    func resolve() throws -> ResolvedField {
        ResolvedField(
            type: try resolveFieldType(schema.fieldType(fieldSchema)),
            deprecation: fieldSchema.deprecation,
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
            return try resolveSelectionSet(on: .OBJECT(objectType))
        case .INTERFACE(let interfaceType):
            return try resolveSelectionSet(on: .INTERFACE(interfaceType))
        case .UNION(let unionType):
            return try resolveSelectionSet(on: .UNION(unionType))
        case .ENUM(let `enum`):
            return .scalar(typeName: `enum`.ast.name, isEnum: true)
        case .LIST(let innerType):
            return .list(innerType: try resolveFieldType(innerType))
        }
    }

    private func resolveSelectionSet(on type: Schema.SelectionSet) throws -> ResolvedFieldType {
        guard let selectionSet = fieldSelection.selectionSet else {
            throw missingSelectionSetError()
        }
        return .map(
            try SelectionSetResolver(
                onType: type,
                selectionSet: selectionSet,
                schema: schema,
                documents: documents
            ).resolve()
        )
    }

    private func missingSelectionSetError() -> Codegen.Error {
        Codegen.Error(description: "Selected field \(schemaCoordinate), which requires a selection set.")
    }
}
