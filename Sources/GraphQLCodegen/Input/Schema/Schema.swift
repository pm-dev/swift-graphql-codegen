import Foundation
import OrderedCollections

struct Schema {
    struct Object {
        let ast: __Schema.__NamedType.Object
        let fields: [String: __Schema.__Field]
        let implements: Set<String>
    }

    struct Scalar {
        let ast: __Schema.__NamedType.Scalar
    }

    struct Interface {
        let ast: __Schema.__NamedType.Interface
        let fields: [String: __Schema.__Field]
        let implements: Set<String>
    }

    struct Union {
        let ast: __Schema.__NamedType.Union
        let possibleTypes: Set<String>
    }

    struct Enum {
        let ast: __Schema.__NamedType.Enum
    }

    struct InputObject {
        let ast: __Schema.__NamedType.InputObject
    }

    enum SelectionSet {
        case OBJECT(Object)
        case INTERFACE(Interface)
        case UNION(Union)

        var name: String {
            switch self {
            case .OBJECT(let object): object.ast.name
            case .INTERFACE(let interface): interface.ast.name
            case .UNION(let union): union.ast.name
            }
        }

        func field(_ field: GraphQLAST.Field) throws -> __Schema.__Field {
            func error() -> Codegen.Error {
                Codegen.Error(description: "Selected field '\(field.name.value)' that doesn't exist on \(name).")
            }
            switch self {
            case .OBJECT(let object):
                guard let field = object.fields[field.name.value] else { throw error() }
                return field
            case .INTERFACE(let interface):
                guard let field = interface.fields[field.name.value] else { throw error() }
                return field
            case .UNION(let union):
                throw Codegen.Error(description: """
                Unexpectedly querying a field \(field.responseKey) directly from a union type \(union.ast.name).
                Fields may not be queried directly from union types.
                https://spec.graphql.org/September2025/#sel-EAHdJCApHCCiDzyP
                """)
            }
        }
    }

    indirect enum Field {
        case nullable(Value)
        case nonNull(Value)

        indirect enum Value {
            case SCALAR(Scalar)
            case OBJECT(Object)
            case INTERFACE(Interface)
            case UNION(Union)
            case ENUM(Enum)
            case LIST(Field)
        }
    }

    indirect enum Input {
        case nullable(Value)
        case nonNull(Value)

        indirect enum Value {
            case SCALAR(Scalar)
            case ENUM(Enum)
            case INPUT_OBJECT(InputObject)
            case LIST(Input)
        }

        var value: Value {
            switch self {
            case .nonNull(let value), .nullable(let value): value
            }
        }
    }

    let queryTypeRef: __Schema.__TypeRef.Object
    let mutationTypeRef: __Schema.__TypeRef.Object?
    let subscriptionTypeRef: __Schema.__TypeRef.Object?
    let typeCache: TypeCache

    func queryType() throws -> Object {
        try type(queryTypeRef)
    }

    func mutationType() throws -> Object? {
        guard let mutationTypeRef else { return nil }
        return try type(mutationTypeRef)
    }

    func subscriptionType() throws -> Object? {
        guard let subscriptionTypeRef else { return nil }
        return try type(subscriptionTypeRef)
    }

    func operationType(_ operation: Document.Operation) throws -> Object {
        switch operation.ast.operation {
        case .query:
            try queryType()
        case .mutation:
            try mutationType() ?? {
                throw invalidOperationError(operation)
            }()
        case .subscription:
            try subscriptionType() ?? {
                throw invalidOperationError(operation)
            }()
        }
    }

    func fieldType(_ type: __Schema.__Field) throws -> Field {
        try fieldType(type.type)
    }

    func isFragment(
        _ fragmentSpreadType: SelectionSet,
        alwaysFulfilledBy baseType: SelectionSet
    ) -> Bool {
        if baseType.name == fragmentSpreadType.name {
            return true
        }
        return switch baseType {
        case .OBJECT(let object):
            switch fragmentSpreadType {
            case .OBJECT: false
            case .INTERFACE(let interface): object.implements.contains(interface.ast.name)
            case .UNION(let union): union.possibleTypes.contains(object.ast.name)
            }
        case .INTERFACE(let interface):
            switch fragmentSpreadType {
            case .OBJECT: false
            case .INTERFACE(let fragmentInterface): interface.implements.contains(fragmentInterface.ast.name)
            case .UNION: false
            }
        case .UNION: false
        }
    }

    func fragmentType(_ inline: GraphQLAST.InlineFragment) throws -> SelectionSet? {
        guard let typeCondition = inline.typeCondition else { return nil }
        return try fragmentType(typeCondition)
    }

    func fragmentType(_ definition: GraphQLAST.FragmentDefinition) throws -> SelectionSet {
        try fragmentType(definition.typeCondition)
    }

    func inputType(_ variableDefinition: GraphQLAST.VariableDefinition) throws -> Input {
        try inputType(variableDefinition.type)
    }

    func inputType(_ inputValue: __Schema.__InputValue) throws -> Input {
        try inputType(inputValue.type)
    }

    private func fieldType(_ typeRef: __Schema.__TypeRef) throws -> Field {
        switch typeRef {
        case .SCALAR(let scalar): try .nullable(.SCALAR(type(scalar)))
        case .ENUM(let `enum`): try .nullable(.ENUM(type(`enum`)))
        case .OBJECT(let objectType): try .nullable(.OBJECT(type(objectType)))
        case .INTERFACE(let interfaceType): try .nullable(.INTERFACE(type(interfaceType)))
        case .UNION(let unionType): try .nullable(.UNION(type(unionType)))
        case .LIST(let ofType): try .nullable(.LIST(fieldType(ofType)))
        case .NON_NULL(let ofType): try .nonNull(fieldValue(ofType))
        case .INPUT_OBJECT:
            throw Codegen.Error(description: """
            Selected a field \(typeRef) whose type is an input object.
            Input objects are not supported as field types
            https://spec.graphql.org/September2025/#sec-Input-Objects.Result-Coercion
            """)
        }
    }

    private func fieldValue(_ typeRef: __Schema.__NullableTypeRef) throws -> Field.Value {
        switch typeRef {
        case .SCALAR(let scalar): try .SCALAR(type(scalar))
        case .ENUM(let `enum`): try .ENUM(type(`enum`))
        case .OBJECT(let objectType): try .OBJECT(type(objectType))
        case .INTERFACE(let interfaceType): try .INTERFACE(type(interfaceType))
        case .UNION(let unionType): try .UNION(type(unionType))
        case .LIST(let ofType): try .LIST(fieldType(ofType))
        case .INPUT_OBJECT:
            throw Codegen.Error(description: "Invalid output type \(typeRef)")
        }
    }

    private func fragmentType(_ type: GraphQLAST.NamedType) throws -> SelectionSet {
        let name = type.name.value
        if let objectType = typeCache.objects[name] {
            return .OBJECT(objectType)
        } else if let interfaceType = typeCache.interfaces[name] {
            return .INTERFACE(interfaceType)
        } else if let unionType = typeCache.unions[name] {
            return .UNION(unionType)
        } else {
            throw Codegen.Error(description: """
            Fragment was specified on type `\(name)`.
            Fragments must be specified on a valid object, interface or union type.
            https://spec.graphql.org/September2025/#sel-GAFddJABeBiC2vU
            """)
        }
    }

    private func inputType(_ typeNode: GraphQLAST.TypeNode) throws -> Input {
        switch typeNode {
        case .named(let namedType): try .nullable(inputValue(namedType))
        case .list(let listType): try .nullable(.LIST(inputType(listType.type)))
        case .nonNull(let nonNullType): try .nonNull(inputValue(nonNullType.type))
        }
    }

    private func inputValue(_ typeNode: GraphQLAST.NullableTypeNode) throws -> Input.Value {
        switch typeNode {
        case .named(let namedType): try inputValue(namedType)
        case .list(let listType): try .LIST(inputType(listType.type))
        }
    }

    private func inputValue(_ namedType: GraphQLAST.NamedType) throws -> Input.Value {
        let name = namedType.name.value
        if let scalarType = typeCache.scalars[name] {
            return .SCALAR(scalarType)
        } else if let enumType = typeCache.enums[name] {
            return .ENUM(enumType)
        } else if let inputObjectType = typeCache.inputObjects[name] {
            return .INPUT_OBJECT(inputObjectType)
        } else {
            throw Codegen.Error(description: "Could not find input type named `\(name)` in schema")
        }
    }

    private func inputType(_ typeRef: __Schema.__TypeRef) throws -> Input {
        switch typeRef {
        case .SCALAR(let scalar): try .nullable(.SCALAR(type(scalar)))
        case .ENUM(let `enum`): try .nullable(.ENUM(type(`enum`)))
        case .INPUT_OBJECT(let inputObject): try .nullable(.INPUT_OBJECT(type(inputObject)))
        case .LIST(let ofType): try .nullable(.LIST(inputType(ofType)))
        case .NON_NULL(let ofType): try .nonNull(inputValue(ofType))
        case .INTERFACE, .OBJECT, .UNION: throw Codegen.Error(description: "Invalid Input Type \(typeRef)")
        }
    }

    private func inputValue(_ typeRef: __Schema.__NullableTypeRef) throws -> Input.Value {
        switch typeRef {
        case .SCALAR(let scalar): try .SCALAR(type(scalar))
        case .ENUM(let `enum`): try .ENUM(type(`enum`))
        case .INPUT_OBJECT(let inputObject): try .INPUT_OBJECT(type(inputObject))
        case .LIST(let ofType): try .LIST(inputType(ofType))
        case .INTERFACE, .OBJECT, .UNION:
            throw Codegen.Error(description: "Invalid input type \(typeRef)")
        }
    }

    private func type(_ ref: __Schema.__TypeRef.Scalar) throws -> Scalar {
        guard let type = typeCache.scalars[ref.name] else {
            throw invalidSchemaError(ref.name)
        }
        return type
    }

    private func type(_ ref: __Schema.__TypeRef.Object) throws -> Object {
        guard let type = typeCache.objects[ref.name] else {
            throw invalidSchemaError(ref.name)
        }
        return type
    }

    private func type(_ ref: __Schema.__TypeRef.Interface) throws -> Interface {
        guard let type = typeCache.interfaces[ref.name] else {
            throw invalidSchemaError(ref.name)
        }
        return type
    }

    private func type(_ ref: __Schema.__TypeRef.Union) throws -> Union {
        guard let type = typeCache.unions[ref.name] else {
            throw invalidSchemaError(ref.name)
        }
        return type
    }

    private func type(_ ref: __Schema.__TypeRef.Enum) throws -> Enum {
        guard let type = typeCache.enums[ref.name] else {
            throw invalidSchemaError(ref.name)
        }
        return type
    }

    private func type(_ ref: __Schema.__TypeRef.InputObject) throws -> InputObject {
        guard let type = typeCache.inputObjects[ref.name] else {
            throw invalidSchemaError(ref.name)
        }
        return type
    }

    private func invalidSchemaError(_ typeRef: String) -> Codegen.Error {
        Codegen.Error(description: "Invalid Schema. Contained a typeRef named \(typeRef) with no corresponding type")
    }

    private func invalidOperationError(_ operation: Document.Operation) -> Codegen.Error {
        Codegen.Error(description: """
        Invalid Operation \(operation.ast.name?.value ?? "")
        The GraphQL schema does not support \(operation.ast.operation) operations
        """)
    }
}
