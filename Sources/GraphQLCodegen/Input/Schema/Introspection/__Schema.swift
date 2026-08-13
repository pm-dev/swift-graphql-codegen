// periphery:ignore:all - Retain the complete schema projection for future codegen features.
/// Mirrors the schema introspection response produced by `IntrospectionQuery`.
///
/// Keep this boundary model aligned with:
/// https://spec.graphql.org/September2025/#sec-Schema-Introspection.Schema-Introspection-Schema
struct __Schema: Decodable {
    enum __NamedType: Decodable {
        case SCALAR(Scalar)
        case OBJECT(Object)
        case INTERFACE(Interface)
        case UNION(Union)
        case ENUM(Enum)
        case INPUT_OBJECT(InputObject)

        struct Scalar: Decodable {
            let description: String?
            let name: String
            let specifiedByURL: String?

            var requiresGeneratedTypeDefinition: Bool {
                name == "ID" || SourceTypeName(nativeGraphQLScalarName: name) == nil
            }

            var swiftName: String {
                SourceTypeName(nativeGraphQLScalarName: name)?.formatted() ?? name
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
            let possibleTypes: [__TypeRef.Object] // https://spec.graphql.org/September2025/#sec-Unions.Type-Validation
        }

        struct Enum: Decodable {
            private static let typeSystemEnums: Set = ["__TypeKind", "__DirectiveLocation"]

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
            let isOneOf: Bool
        }

        private enum CodingKeys: CodingKey {
            case kind
        }

        init(from decoder: Decoder) throws {
            func _container() throws -> SingleValueDecodingContainer {
                try decoder.singleValueContainer()
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(__NamedTypeKind.self, forKey: .kind) {
            case .SCALAR: self = try .SCALAR(_container().decode(Scalar.self))
            case .OBJECT: self = try .OBJECT(_container().decode(Object.self))
            case .INTERFACE: self = try .INTERFACE(_container().decode(Interface.self))
            case .UNION: self = try .UNION(_container().decode(Union.self))
            case .ENUM: self = try .ENUM(_container().decode(Enum.self))
            case .INPUT_OBJECT: self = try .INPUT_OBJECT(_container().decode(InputObject.self))
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
        case NON_NULL(ofType: __NullableTypeRef)

        struct Scalar: Decodable {
            let name: String

            var swiftName: String {
                SourceTypeName(nativeGraphQLScalarName: name)?.formatted() ?? name
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
            case .NON_NULL(let innerType): return innerType.swiftName
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
            case .NON_NULL:
                self = try .NON_NULL(ofType: container.decode(__NullableTypeRef.self, forKey: .ofType))
            }
        }
    }

    indirect enum __NullableTypeRef: Decodable {
        case SCALAR(__TypeRef.Scalar)
        case OBJECT(__TypeRef.Object)
        case INTERFACE(__TypeRef.Interface)
        case UNION(__TypeRef.Union)
        case ENUM(__TypeRef.Enum)
        case INPUT_OBJECT(__TypeRef.InputObject)
        case LIST(ofType: __TypeRef)

        var swiftName: SourceTypeName {
            switch self {
            case .SCALAR(let scalar): .name(scalar.swiftName)
            case .OBJECT(let object): .name(object.name)
            case .INTERFACE(let interface): .name(interface.name)
            case .UNION(let union): .name(union.name)
            case .ENUM(let `enum`): .name(`enum`.name)
            case .INPUT_OBJECT(let inputObject): .name(inputObject.name)
            case .LIST(let innerType): .list(innerType.swiftName)
            }
        }

        init(from decoder: Decoder) throws {
            switch try __TypeRef(from: decoder) {
            case .SCALAR(let scalar): self = .SCALAR(scalar)
            case .OBJECT(let object): self = .OBJECT(object)
            case .INTERFACE(let interface): self = .INTERFACE(interface)
            case .UNION(let union): self = .UNION(union)
            case .ENUM(let `enum`): self = .ENUM(`enum`)
            case .INPUT_OBJECT(let inputObject): self = .INPUT_OBJECT(inputObject)
            case .LIST(let innerType): self = .LIST(ofType: innerType)
            case .NON_NULL:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "A non-null type cannot wrap another non-null type"
                    )
                )
            }
        }
    }

    struct __Directive: Decodable {
        let name: String
        let description: String?
        let args: [__InputValue]
        let isRepeatable: Bool
    }

    struct __Field: Decodable {
        let name: String
        let description: String?
        let args: [__InputValue]
        let type: __TypeRef
        let deprecation: Deprecation?
    }

    struct __EnumValue: Decodable {
        let name: String
        let description: String?
        let deprecation: Deprecation?
    }

    struct __InputValue: Decodable {
        let name: String
        let description: String?
        let type: __TypeRef
        let defaultValue: String?
        let deprecation: Deprecation?
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

    private enum __NamedTypeKind: String, Decodable {
        case SCALAR
        case OBJECT
        case INTERFACE
        case UNION
        case ENUM
        case INPUT_OBJECT
    }

    let description: String?
    let types: [__NamedType]
    let queryType: __TypeRef.Object
    let mutationType: __TypeRef.Object?
    let subscriptionType: __TypeRef.Object?
    let directives: [__Directive]
}

private enum IntrospectionDeprecationCodingKeys: String, CodingKey {
    case args
    case defaultValue
    case deprecationReason
    case description
    case isDeprecated
    case name
    case type
}

extension Deprecation {
    fileprivate init?(introspection decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: IntrospectionDeprecationCodingKeys.self)
        guard try container.decode(Bool.self, forKey: .isDeprecated) else {
            guard try container.decodeIfPresent(String.self, forKey: .deprecationReason) == nil else {
                throw DecodingError.dataCorruptedError(
                    forKey: .deprecationReason,
                    in: container,
                    debugDescription: "A nondeprecated schema member cannot have a deprecation reason"
                )
            }
            return nil
        }
        reason = try container.decode(String.self, forKey: .deprecationReason)
    }
}

extension __Schema.__Field {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: IntrospectionDeprecationCodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        args = try container.decode([__Schema.__InputValue].self, forKey: .args)
        type = try container.decode(__Schema.__TypeRef.self, forKey: .type)
        deprecation = try Deprecation(introspection: decoder)
    }
}

extension __Schema.__EnumValue {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: IntrospectionDeprecationCodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        deprecation = try Deprecation(introspection: decoder)
    }
}

extension __Schema.__InputValue {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: IntrospectionDeprecationCodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        type = try container.decode(__Schema.__TypeRef.self, forKey: .type)
        defaultValue = try container.decodeIfPresent(String.self, forKey: .defaultValue)
        deprecation = try Deprecation(introspection: decoder)
    }
}

extension __Schema {
    func applying(_ policy: Configuration.Input.DeprecationPolicy) -> Self {
        switch policy {
        case .include: self
        case .exclude:
            Self(
                description: description,
                types: types.map { $0.applying(policy) },
                queryType: queryType,
                mutationType: mutationType,
                subscriptionType: subscriptionType,
                directives: directives.map { $0.applying(policy) }
            )
        }
    }
}

extension __Schema.__NamedType {
    fileprivate func applying(_ policy: Configuration.Input.DeprecationPolicy) -> Self {
        switch self {
        case .SCALAR, .UNION: self
        case .OBJECT(let object):
            .OBJECT(
                Object(
                    description: object.description,
                    name: object.name,
                    fields: object.fields.compactMap { $0.applying(policy) },
                    interfaces: object.interfaces
                )
            )
        case .INTERFACE(let interface):
            .INTERFACE(
                Interface(
                    description: interface.description,
                    name: interface.name,
                    fields: interface.fields.compactMap { $0.applying(policy) },
                    interfaces: interface.interfaces
                )
            )
        case .ENUM(let `enum`):
            .ENUM(
                Enum(
                    description: `enum`.description,
                    name: `enum`.name,
                    enumValues: `enum`.enumValues.compactMap { $0.applying(policy) }
                )
            )
        case .INPUT_OBJECT(let inputObject):
            .INPUT_OBJECT(
                InputObject(
                    description: inputObject.description,
                    name: inputObject.name,
                    inputFields: inputObject.inputFields.compactMap { $0.applying(policy) },
                    isOneOf: inputObject.isOneOf
                )
            )
        }
    }
}

extension __Schema.__Field {
    fileprivate func applying(_ policy: Configuration.Input.DeprecationPolicy) -> Self? {
        switch policy {
        case .include: return self
        case .exclude:
            guard deprecation == nil else { return nil }
            return Self(
                name: name,
                description: description,
                args: args.compactMap { $0.applying(policy) },
                type: type,
                deprecation: nil
            )
        }
    }
}

extension __Schema.__Directive {
    fileprivate func applying(_ policy: Configuration.Input.DeprecationPolicy) -> Self {
        Self(
            name: name,
            description: description,
            args: args.compactMap { $0.applying(policy) },
            isRepeatable: isRepeatable
        )
    }
}

extension __Schema.__EnumValue {
    fileprivate func applying(_ policy: Configuration.Input.DeprecationPolicy) -> Self? {
        switch policy {
        case .include: self
        case .exclude: deprecation == nil ? self : nil
        }
    }
}

extension __Schema.__InputValue {
    fileprivate func applying(_ policy: Configuration.Input.DeprecationPolicy) -> Self? {
        switch policy {
        case .include: self
        case .exclude: deprecation == nil ? self : nil
        }
    }
}
