import Foundation

/// https://github.com/graphql/graphql-js/blob/16.x.x/src/language/ast.ts
enum AST {
    struct Location: Decodable, Hashable {
        let start: Int
        let end: Int

        var range: Range<Int> {
            start..<end
        }
    }

    struct Name: Decodable {
        let loc: Location
        let value: String
    }

    struct Document: Decodable {
        let loc: Location
        let definitions: [Definition]
    }

    enum Definition: Decodable {
        case operation(OperationDefinition)
        case fragment(FragmentDefinition)

        private enum Kind: String, Decodable {
            case OperationDefinition
            case FragmentDefinition
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            switch try decoder.container(keyedBy: KindCodingKey.self).decode(Kind.self, forKey: .kind) {
            case .OperationDefinition: self = try .operation(container.decode(OperationDefinition.self))
            case .FragmentDefinition: self = try .fragment(container.decode(FragmentDefinition.self))
            }
        }
    }

    struct OperationDefinition: Decodable, Sendable {
        let loc: Location
        let operation: OperationType
        let name: Name?
        let variableDefinitions: [VariableDefinition]
        let directives: [Directive]
        let selectionSet: SelectionSet
    }

    enum OperationType: String, Decodable {
        case query
        case mutation
        case subscription
    }

    struct VariableDefinition: Decodable, Sendable {
        let loc: Location
        let variable: Variable
        let type: TypeNode
        let defaultValue: ConstValue?
        let directives: [ConstDirective]?
    }

    struct Variable: Decodable {
        let loc: Location
        let name: Name
    }

    struct SelectionSet: Decodable, Sendable {
        let loc: Location
        let selections: [Selection]
    }

    enum Selection: Decodable {
        case field(Field)
        case fragmentSpread(FragmentSpread)
        case inlineFragment(InlineFragment)

        private enum Kind: String, Decodable {
            case Field
            case FragmentSpread
            case InlineFragment
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            switch try decoder.container(keyedBy: KindCodingKey.self).decode(Kind.self, forKey: .kind) {
            case .Field: self = try .field(container.decode(Field.self))
            case .FragmentSpread: self = try .fragmentSpread(container.decode(FragmentSpread.self))
            case .InlineFragment: self = try .inlineFragment(container.decode(InlineFragment.self))
            }
        }
    }

    struct Field: Decodable {
        let loc: Location
        let alias: Name?
        let name: Name
        let arguments: [Argument]
        let directives: [Directive]
        let selectionSet: SelectionSet?

        var responseKey: String {
            (alias ?? name).value
        }
    }

    struct Argument: Decodable, Sendable {
        let loc: Location
        let name: Name
        let value: Value
    }

    struct ConstArgument: Decodable {
        let loc: Location
        let name: Name
        let value: ConstValue
    }

    struct FragmentSpread: Decodable {
        let loc: Location
        let name: Name
        let directives: [Directive]
    }

    struct InlineFragment: Decodable {
        let loc: Location
        let typeCondition: NamedType?
        let directives: [Directive]
        let selectionSet: SelectionSet
    }

    struct FragmentDefinition: Decodable {
        let loc: Location
        let name: Name
        let typeCondition: NamedType
        let directives: [Directive]
        let selectionSet: SelectionSet
    }

    enum Value: Decodable, Sendable {
        case variable(Variable)
        case int(IntValue)
        case float(FloatValue)
        case string(StringValue)
        case boolean(BooleanValue)
        case null(NullValue)
        case `enum`(EnumValue)
        case list(ListValue)
        case object(ObjectValue)

        private enum Kind: String, Decodable {
            case Variable
            case IntValue
            case FloatValue
            case StringValue
            case BooleanValue
            case NullValue
            case EnumValue
            case ListValue
            case ObjectValue
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            switch try decoder.container(keyedBy: KindCodingKey.self).decode(Kind.self, forKey: .kind) {
            case .Variable: self = try .variable(container.decode(Variable.self))
            case .IntValue: self = try .int(container.decode(IntValue.self))
            case .FloatValue: self = try .float(container.decode(FloatValue.self))
            case .StringValue: self = try .string(container.decode(StringValue.self))
            case .BooleanValue: self = try .boolean(container.decode(BooleanValue.self))
            case .NullValue: self = try .null(container.decode(NullValue.self))
            case .EnumValue: self = try .enum(container.decode(EnumValue.self))
            case .ListValue: self = try .list(container.decode(ListValue.self))
            case .ObjectValue: self = try .object(container.decode(ObjectValue.self))
            }
        }
    }

    enum ConstValue: Decodable, Sendable {
        case int(IntValue)
        case float(FloatValue)
        case string(StringValue)
        case boolean(BooleanValue)
        case null(NullValue)
        case `enum`(EnumValue)
        case list(ConstListValue)
        case object(ConstObjectValue)

        private enum Kind: String, Decodable {
            case IntValue
            case FloatValue
            case StringValue
            case BooleanValue
            case NullValue
            case EnumValue
            case ListValue
            case ObjectValue
        }

        var description: String {
            switch self {
            case .int(let intValue): return "\(intValue.value)"
            case .float(let floatValue): return "\(floatValue.value)"
            case .string(let stringValue): return "\"\(stringValue.value)\""
            case .boolean(let booleanValue): return "\(booleanValue.value)"
            case .null: return "null"
            case .enum(let enumValue): return "\(enumValue.value)"
            case .list(let list):
                var str = "["
                str.append(list.values.map(\.description).joined(separator: ", "))
                str.append("]")
                return str
            case .object(let object):
                var str = "["
                str.append(object.fields.map { "\($0.name): \($0.value.description)" }.joined(separator: ", "))
                str.append("]")
                return str
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            switch try decoder.container(keyedBy: KindCodingKey.self).decode(Kind.self, forKey: .kind) {
            case .IntValue: self = try .int(container.decode(IntValue.self))
            case .FloatValue: self = try .float(container.decode(FloatValue.self))
            case .StringValue: self = try .string(container.decode(StringValue.self))
            case .BooleanValue: self = try .boolean(container.decode(BooleanValue.self))
            case .NullValue: self = try .null(container.decode(NullValue.self))
            case .EnumValue: self = try .enum(container.decode(EnumValue.self))
            case .ListValue: self = try .list(container.decode(ConstListValue.self))
            case .ObjectValue: self = try .object(container.decode(ConstObjectValue.self))
            }
        }
    }

    struct IntValue: Decodable {
        let loc: Location
        let value: String
    }

    struct FloatValue: Decodable {
        let loc: Location
        let value: String
    }

    struct StringValue: Decodable {
        let value: String
        let loc: Location
    }

    struct BooleanValue: Decodable {
        let loc: Location
        let value: Bool
    }

    struct NullValue: Decodable {
        let loc: Location
    }

    struct EnumValue: Decodable {
        let loc: Location
        let value: String
    }

    struct ListValue: Decodable {
        let loc: Location
        let values: [Value]
    }

    struct ConstListValue: Decodable {
        let loc: Location
        let values: [ConstValue]
    }

    struct ObjectValue: Decodable {
        let loc: Location
        let fields: [ObjectField]
    }

    struct ConstObjectValue: Decodable {
        let loc: Location
        let fields: [ConstObjectField]
    }

    struct ObjectField: Decodable {
        let loc: Location
        let name: Name
        let value: Value
    }

    struct ConstObjectField: Decodable {
        let loc: Location
        let name: Name
        let value: ConstValue
    }

    struct Directive: Decodable, Sendable {
        let loc: Location
        let name: Name
        let arguments: [Argument]?
    }

    struct ConstDirective: Decodable {
        let loc: Location
        let name: Name
        let arguments: [ConstArgument]?
    }

    indirect enum TypeNode: Decodable, Sendable {
        case named(NamedType)
        case list(ListType)
        case nonNull(NonNullType)

        private enum Kind: String, Decodable {
            case NamedType
            case ListType
            case NonNullType
        }

        var typeName: SourceTypeName {
            switch self {
            case .named(let namedType): return .optional(.name(namedType.name.value))
            case .list(let innerType): return .optional(.list(innerType.type.typeName))
            case .nonNull(let innerType):
                let resolved = innerType.type.typeName
                switch resolved {
                case .optional(let unwrapped): return unwrapped
                case .list, .name: return resolved // Already non-null
                }
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            switch try decoder.container(keyedBy: KindCodingKey.self).decode(Kind.self, forKey: .kind) {
            case .NamedType: self = try .named(container.decode(NamedType.self))
            case .ListType: self = try .list(container.decode(ListType.self))
            case .NonNullType: self = try .nonNull(container.decode(NonNullType.self))
            }
        }
    }

    struct NamedType: Decodable {
        let loc: Location
        let name: Name
    }

    struct ListType: Decodable {
        let loc: Location
        let type: TypeNode
    }

    struct NonNullType: Decodable {
        let loc: Location
        let type: TypeNode
    }

    private enum KindCodingKey: String, CodingKey {
        case kind
    }
}
