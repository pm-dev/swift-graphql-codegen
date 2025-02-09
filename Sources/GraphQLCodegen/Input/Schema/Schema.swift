import Foundation
import OrderedCollections

struct Schema {
    let jsonString: String?
    let queryTypeRef: __Schema.__TypeRef.Object
    let mutationTypeRef: __Schema.__TypeRef.Object?
    let subscriptionTypeRef: __Schema.__TypeRef.Object?
    let typeCache: TypeCache

    struct Object {
        let ast: __Schema.__Type.Object
        let fields: [String: __Schema.__Field]
        let implements: Set<String>
    }

    struct Scalar {
        let ast: __Schema.__Type.Scalar
    }

    struct Interface {
        let ast: __Schema.__Type.Interface
        let fields: [String: __Schema.__Field]
        let implements: Set<String>
    }

    struct Union {
        let ast: __Schema.__Type.Union
        let possibleTypes: Set<String>
    }

    struct Enum {
        let ast: __Schema.__Type.Enum
    }

    struct InputObject {
        let ast: __Schema.__Type.InputObject
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

        func field(_ field: AST.Field) throws -> __Schema.__Field {
            func error() -> Codegen.Error {
                Codegen.Error(description: """
                Selected field '\(field.name.value)' that doesn't exist on \(name).

                Note: Turn on validation for more debuggable error descriptions and to find other similar errors
                """)
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
                https://spec.graphql.org/October2021/#sel-EAHdJDBAACCiDzyP

                Turn on type validation to catch errors like this.
                """)
            }
        }
    }

    indirect enum Field {
        case SCALAR(Scalar)
        case OBJECT(Object)
        case INTERFACE(Interface)
        case UNION(Union)
        case ENUM(Enum)
        case LIST(Field)
        case NON_NULL(Field)
    }

    indirect enum Input {
        case SCALAR(Scalar)
        case ENUM(Enum)
        case INPUT_OBJECT(InputObject)
        case LIST(Input)
        case NON_NULL(Input)
    }

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

    private func fieldType(_ typeRef: __Schema.__TypeRef) throws -> Field {
        switch typeRef {
        case .SCALAR(let scalar): .SCALAR(try type(scalar))
        case .ENUM(let `enum`): .ENUM(try type(`enum`))
        case .OBJECT(let objectType): .OBJECT(try type(objectType))
        case .INTERFACE(let interfaceType): .INTERFACE(try type(interfaceType))
        case .UNION(let unionType): .UNION(try type(unionType))
        case .LIST(let ofType): .LIST(try fieldType(ofType))
        case .NON_NULL(let ofType): .NON_NULL(try fieldType(ofType))
        case .INPUT_OBJECT:
            throw Codegen.Error(description: """
            Selected a field \(typeRef) whose type is an input object.
            Input objects are not supported as field types
            https://spec.graphql.org/October2021/#sec-Input-Objects.Result-Coercion

            Note: Turning on validation can help find other similar errors
            """)
        }
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

    func fragmentType(_ inline: AST.InlineFragment) throws -> SelectionSet? {
        guard let typeCondition = inline.typeCondition else { return nil }
        return try fragmentType(typeCondition)
    }

    func fragmentType(_ definition: AST.FragmentDefinition) throws -> SelectionSet {
        try fragmentType(definition.typeCondition)
    }

    private func fragmentType(_ type: AST.NamedType) throws -> SelectionSet {
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
            https://spec.graphql.org/October2021/#sel-GAFbdJABeBiC2vU

            Note: Turning on validation can help find other similar errors
            """)
        }
    }

    func inputType(_ variableDefinition: AST.VariableDefinition) throws -> Input {
        try inputType(variableDefinition.type)
    }

    func inputType(_ inputValue: __Schema.__InputValue) throws -> Input {
        try inputType(inputValue.type)
    }

    private func inputType(_ typeNode: AST.TypeNode) throws -> Input {
        switch typeNode {
        case .named(let namedType): try inputType(namedType)
        case .list(let listType): .LIST(try inputType(listType.type))
        case .nonNull(let nonNullType): .NON_NULL(try inputType(nonNullType.type))
        }
    }

    private func inputType(_ namedType: AST.NamedType) throws -> Input {
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
        case .SCALAR(let scalar): .SCALAR(try type(scalar))
        case .ENUM(let `enum`): .ENUM(try type(`enum`))
        case .INPUT_OBJECT(let inputObject): .INPUT_OBJECT(try type(inputObject))
        case .LIST(let ofType): .LIST(try inputType(ofType))
        case .NON_NULL(let ofType): .NON_NULL(try inputType(ofType))
        case .INTERFACE, .OBJECT, .UNION: throw Codegen.Error(description: "Invalid Input Type \(typeRef)")
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

        Note: Turning on validation can help find other similar errors
        """)
    }
}
