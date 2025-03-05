/// https://spec.graphql.org/October2021/#sec-Schema-Introspection.Schema-Introspection-Schema
struct __Schema: Decodable {
    enum __Type: Decodable {
        case SCALAR(Scalar)
        case OBJECT(Object)
        case INTERFACE(Interface)
        case UNION(Union)
        case ENUM(Enum)
        case INPUT_OBJECT(InputObject)
        case LIST(ofType: __TypeRef)
        case NON_NULL(ofType: __TypeRef)

        struct Scalar: Decodable {
            let description: String?
            let name: String
            let specifiedByURL: String?

            var isNativeSwiftType: Bool {
                SourceTypeName.swiftNativeScalar(graphQLScalarName: name) != nil
            }

            var swiftName: String {
                SourceTypeName.swiftNativeScalar(graphQLScalarName: name) ?? name
            }
        }

        struct Object: Decodable {
            let description: String?
            let name: String
            let fields: [__Field]
            let interfaces: [__TypeRef.Interface]
        }

        struct Interface: Decodable {
            let description: String?
            let name: String
            let fields: [__Field]
            let interfaces: [__TypeRef.Interface]
        }

        struct Union: Decodable {
            let description: String?
            let name: String
            let possibleTypes: [__TypeRef.Object] // https://spec.graphql.org/October2021/#sec-Unions.Type-Validation
        }

        struct Enum: Decodable {
            private static let typeSystemEnums: Set<String> = ["__TypeKind", "__DirectiveLocation"]

            let description: String?
            let name: String
            let enumValues: [__EnumValue]

            var isSystemType: Bool {
                Self.typeSystemEnums.contains(name)
            }
        }

        struct InputObject: Decodable {
            let description: String?
            let name: String
            let inputFields: [__InputValue]
        }

        private enum CodingKeys: CodingKey {
            case kind
            case ofType
        }

        var isOptional: Bool {
            switch self {
            case .NON_NULL: false
            default: true
            }
        }

        init(from decoder: Decoder) throws {
            func _container() throws -> SingleValueDecodingContainer {
                try decoder.singleValueContainer()
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(__TypeKind.self, forKey: .kind) {
            case .SCALAR: self = try .SCALAR(_container().decode(Scalar.self))
            case .OBJECT: self = try .OBJECT(_container().decode(Object.self))
            case .INTERFACE: self = try .INTERFACE(_container().decode(Interface.self))
            case .UNION: self = try .UNION(_container().decode(Union.self))
            case .ENUM: self = try .ENUM(_container().decode(Enum.self))
            case .INPUT_OBJECT: self = try .INPUT_OBJECT(_container().decode(InputObject.self))
            case .LIST: self = try .LIST(ofType: container.decode(__TypeRef.self, forKey: .ofType))
            case .NON_NULL: self = try .NON_NULL(ofType: container.decode(__TypeRef.self, forKey: .ofType))
            }
        }
    }

    indirect enum __TypeRef: Decodable {
        case SCALAR(Scalar)
        case OBJECT(Object)
        case INTERFACE(Interface)
        case UNION(Union)
        case ENUM(Enum)
        case INPUT_OBJECT(InputObject)
        case LIST(ofType: __TypeRef)
        case NON_NULL(ofType: __TypeRef)

        struct Scalar: Decodable {
            let name: String

            var swiftName: String {
                SourceTypeName.swiftNativeScalar(graphQLScalarName: name) ?? name
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let kind = try container.decode(__TypeKind.self, forKey: .kind)
                guard kind == .SCALAR else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .kind,
                        in: container,
                        debugDescription: "Expected .SCALAR but found .\(kind)"
                    )
                }
                self.name = try container.decode(String.self, forKey: .name)
            }
        }

        struct Object: Decodable {
            let name: String

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.name = try container.decode(String.self, forKey: .name)
            }
        }

        struct Interface: Decodable {
            let name: String

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let kind = try container.decode(__TypeKind.self, forKey: .kind)
                guard kind == .INTERFACE else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .kind,
                        in: container,
                        debugDescription: "Expected .INTERFACE but found .\(kind)"
                    )
                }
                self.name = try container.decode(String.self, forKey: .name)
            }
        }

        struct Union: Decodable {
            let name: String

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let kind = try container.decode(__TypeKind.self, forKey: .kind)
                guard kind == .UNION else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .kind,
                        in: container,
                        debugDescription: "Expected .UNION but found .\(kind)"
                    )
                }
                self.name = try container.decode(String.self, forKey: .name)
            }
        }

        struct Enum: Decodable {
            let name: String

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let kind = try container.decode(__TypeKind.self, forKey: .kind)
                guard kind == .ENUM else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .kind,
                        in: container,
                        debugDescription: "Expected .ENUM but found .\(kind)"
                    )
                }
                self.name = try container.decode(String.self, forKey: .name)
            }
        }

        struct InputObject: Decodable {
            let name: String

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let kind = try container.decode(__TypeKind.self, forKey: .kind)
                guard kind == .INPUT_OBJECT else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .kind,
                        in: container,
                        debugDescription: "Expected .INPUT_OBJECT but found .\(kind)"
                    )
                }
                self.name = try container.decode(String.self, forKey: .name)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case kind
            case name
            case ofType
        }

        var swiftName: SourceTypeName {
            switch self {
            case .SCALAR(let scalar): return .optional(.name(scalar.swiftName))
            case .OBJECT(let object): return .optional(.name(object.name))
            case .INTERFACE(let interface): return .optional(.name(interface.name))
            case .UNION(let union): return .optional(.name(union.name))
            case .ENUM(let `enum`): return .optional(.name(`enum`.name))
            case .INPUT_OBJECT(let inputObject): return .optional(.name(inputObject.name))
            case .LIST(let innerType): return .optional(.list(innerType.swiftName))
            case .NON_NULL(let innerType):
                let resolved = innerType.swiftName
                switch resolved {
                case .optional(let unwrapped): return unwrapped
                case .list, .name: return resolved // Already non-null
                }
            }
        }

        var isOptional: Bool {
            switch self {
            case .NON_NULL: false
            default: true
            }
        }

        init(from decoder: Decoder) throws {
            func _container() throws -> SingleValueDecodingContainer {
                try decoder.singleValueContainer()
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(__TypeKind.self, forKey: .kind) {
            case .SCALAR: self = try .SCALAR(_container().decode(Scalar.self))
            case .OBJECT: self = try .OBJECT(_container().decode(Object.self))
            case .INTERFACE: self = try .INTERFACE(_container().decode(Interface.self))
            case .UNION: self = try .UNION(_container().decode(Union.self))
            case .ENUM: self = try .ENUM(_container().decode(Enum.self))
            case .INPUT_OBJECT: self = try .INPUT_OBJECT(_container().decode(InputObject.self))
            case .LIST: self = try .LIST(ofType: container.decode(__TypeRef.self, forKey: .ofType))
            case .NON_NULL: self = try .NON_NULL(ofType: container.decode(__TypeRef.self, forKey: .ofType))
            }
        }
    }

    struct __Directive: Decodable {
        let name: String
        let description: String?
        let locations: [__DirectiveLocation]
        let args: [__InputValue]
        let isRepeatable: Bool?
    }

    enum __DirectiveLocation: String, Decodable {
        case QUERY
        case MUTATION
        case SUBSCRIPTION
        case FIELD
        case FRAGMENT_DEFINITION
        case FRAGMENT_SPREAD
        case INLINE_FRAGMENT
        case VARIABLE_DEFINITION
        case SCHEMA
        case SCALAR
        case OBJECT
        case FIELD_DEFINITION
        case ARGUMENT_DEFINITION
        case INTERFACE
        case UNION
        case ENUM
        case ENUM_VALUE
        case INPUT_OBJECT
        case INPUT_FIELD_DEFINITION
    }

    struct __Field: Decodable {
        let name: String
        let description: String?
        let args: [__InputValue]
        let type: __TypeRef
        let isDeprecated: Bool
        let deprecationReason: String?
    }

    struct __EnumValue: Decodable {
        let name: String
        let description: String?
        let isDeprecated: Bool
        let deprecationReason: String?
    }

    struct __InputValue: Decodable {
        let name: String
        let description: String?
        let type: __TypeRef
        let defaultValue: String?
    }

    private enum __TypeKind: String, Decodable {
        case SCALAR
        case OBJECT
        case INTERFACE
        case UNION
        case ENUM
        case INPUT_OBJECT
        case LIST
        case NON_NULL
    }

    let description: String?
    let types: [__Type]
    let queryType: __TypeRef.Object
    let mutationType: __TypeRef.Object?
    let subscriptionType: __TypeRef.Object?
    let directives: [__Directive]
}
