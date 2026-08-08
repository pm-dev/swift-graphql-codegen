import Foundation

/// Mirrors the executable-document AST produced by the bundled graphql-js parser.
///
/// Keep this boundary model aligned with the executable definitions in:
/// https://github.com/graphql/graphql-js/blob/17.x.x/src/language/ast.ts
enum GraphQLAST {
    /// Verified against the bundled graphql-js parser: location offsets are UTF-16 code units.
    struct Location: Decodable, Hashable {
        let start: Int
        let end: Int

        var utf16Range: Range<Int> {
            start..<end
        }
    }

    struct Name: Decodable {
        let value: String
    }

    struct Document: Decodable {
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
        let description: StringValue?
        let operation: OperationType
        let name: Name?
        let variableDefinitions: [VariableDefinition]?
        let selectionSet: SelectionSet
    }

    enum OperationType: String, Decodable {
        case query
        case mutation
        case subscription
    }

    struct VariableDefinition: Decodable, Sendable {
        let description: StringValue?
        let variable: Variable
        let type: TypeNode
        let defaultValue: ConstValue?
    }

    struct Variable: Decodable {
        let name: Name
    }

    struct SelectionSet: Decodable, Sendable {
        let selections: [Selection]
    }

    enum Selection: Decodable {
        case field(Field)
        case fragmentSpread(FragmentSpread)
        case inlineFragment(InlineFragment)

        var hasOptionalDirective: Bool {
            directives.contains {
                $0.name.value == "skip" || $0.name.value == "include"
            }
        }

        private var directives: [Directive] {
            switch self {
            case .field(let field): field.directives ?? []
            case .fragmentSpread(let fragmentSpread): fragmentSpread.directives ?? []
            case .inlineFragment(let inlineFragment): inlineFragment.directives ?? []
            }
        }

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
        let alias: Name?
        let name: Name
        let directives: [Directive]?
        let selectionSet: SelectionSet?

        var responseKey: String {
            (alias ?? name).value
        }
    }

    struct FragmentSpread: Decodable {
        let name: Name
        let directives: [Directive]?
    }

    struct InlineFragment: Decodable {
        let typeCondition: NamedType?
        let directives: [Directive]?
        let selectionSet: SelectionSet
    }

    struct FragmentDefinition: Decodable {
        let loc: Location
        let description: StringValue?
        let name: Name
        let typeCondition: NamedType
        let selectionSet: SelectionSet
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
        let value: String
    }

    struct FloatValue: Decodable {
        let value: String
    }

    struct StringValue: Decodable {
        let value: String
    }

    struct BooleanValue: Decodable {
        let value: Bool
    }

    struct NullValue: Decodable {}

    struct EnumValue: Decodable {
        let value: String
    }

    struct ConstListValue: Decodable {
        let values: [ConstValue]
    }

    struct ConstObjectValue: Decodable {
        let fields: [ConstObjectField]
    }

    struct ConstObjectField: Decodable {
        let name: Name
        let value: ConstValue
    }

    struct Directive: Decodable, Sendable {
        let name: Name
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
            case .named(let namedType): return .optional(
                .name(
                    SourceTypeName(nativeGraphQLScalarName: namedType.name.value)?.formatted() ?? namedType.name.value
                )
            )
            case .list(let innerType): return .optional(.list(innerType.type.typeName))
            case .nonNull(let innerType): return innerType.type.typeName
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
        let name: Name
    }

    struct ListType: Decodable {
        let type: TypeNode
    }

    struct NonNullType: Decodable {
        let type: NullableTypeNode
    }

    indirect enum NullableTypeNode: Decodable {
        case named(NamedType)
        case list(ListType)

        private enum Kind: String, Decodable {
            case NamedType
            case ListType
        }

        var typeName: SourceTypeName {
            switch self {
            case .named(let namedType):
                .name(SourceTypeName(nativeGraphQLScalarName: namedType.name.value)?.formatted() ?? namedType.name.value)
            case .list(let innerType): .list(innerType.type.typeName)
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            switch try decoder.container(keyedBy: KindCodingKey.self).decode(Kind.self, forKey: .kind) {
            case .NamedType: self = try .named(container.decode(NamedType.self))
            case .ListType: self = try .list(container.decode(ListType.self))
            }
        }
    }

    private enum KindCodingKey: String, CodingKey {
        case kind
    }
}
