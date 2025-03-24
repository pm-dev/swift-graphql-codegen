import Foundation

// Type names are guaranteed to be unique
// https://spec.graphql.org/October2021/#sel-FAHTLABDBEmrR
struct TypeASTCache {
    var scalars: [String: __Schema.__Type.Scalar] = [:]
    var objects: [String: __Schema.__Type.Object] = [:]
    var interfaces: [String: __Schema.__Type.Interface] = [:]
    var unions: [String: __Schema.__Type.Union] = [:]
    var enums: [String: __Schema.__Type.Enum] = [:]
    var inputObjects: [String: __Schema.__Type.InputObject] = [:]
    init(_ schema: __Schema) {
        for type in schema.types {
            switch type {
            case .SCALAR(let scalar): scalars[scalar.name] = scalar
            case .OBJECT(let object): objects[object.name] = object
            case .INTERFACE(let interface): interfaces[interface.name] = interface
            case .UNION(let union): unions[union.name] = union
            case .ENUM(let `enum`): enums[`enum`.name] = `enum`
            case .INPUT_OBJECT(let inputObject): inputObjects[inputObject.name] = inputObject
            case .LIST: break
            case .NON_NULL: break
            }
        }
    }
}

struct TypeCache {
    var scalars: [String: Schema.Scalar] = [:]
    var objects: [String: Schema.Object] = [:]
    var interfaces: [String: Schema.Interface] = [:]
    var unions: [String: Schema.Union] = [:]
    var enums: [String: Schema.Enum] = [:]
    var inputObjects: [String: Schema.InputObject] = [:]

    init(_ cache: TypeASTCache) {
        scalars = cache.scalars.mapValues { Schema.Scalar(ast: $0) }
        for (name, ast) in cache.objects {
            var implements: Set<String> = []
            var interfaces = ast.interfaces.map(\.name)
            while let interface = interfaces.popLast() {
                implements.insert(interface)
                if let interface = cache.interfaces[interface] {
                    interfaces.append(contentsOf: interface.interfaces.map(\.name))
                }
            }
            objects[name] = Schema.Object(
                ast: ast,
                fields: ast.fields.reduce(into: [:]) { fields, field in fields[field.name] = field },
                implements: implements
            )
        }
        for (name, ast) in cache.interfaces {
            var implements: Set<String> = []
            var _interfaces = ast.interfaces.map(\.name)
            while let interface = _interfaces.popLast() {
                implements.insert(interface)
                if let interface = cache.interfaces[interface] {
                    _interfaces.append(contentsOf: interface.interfaces.map(\.name))
                }
            }
            interfaces[name] = Schema.Interface(
                ast: ast,
                fields: ast.fields.reduce(into: [:]) { fields, field in fields[field.name] = field },
                implements: implements
            )
        }
        for (name, ast) in cache.unions {
            unions[name] = Schema.Union(
                ast: ast,
                possibleTypes: Set(ast.possibleTypes.map(\.name))
            )
        }
        enums = cache.enums.mapValues { Schema.Enum(ast: $0) }
        inputObjects = cache.inputObjects.mapValues { Schema.InputObject(ast: $0) }
    }
}

struct SchemaLoader {
    let configuration: Configuration

    func load() async throws -> Schema {
        let (jsonString, typedSchema) = try await loadIntrospection()
        return Schema(
            jsonString: jsonString,
            queryTypeRef: typedSchema.queryType,
            mutationTypeRef: typedSchema.mutationType,
            subscriptionTypeRef: typedSchema.subscriptionType,
            typeCache: TypeCache(TypeASTCache(typedSchema))
        )
    }

    private func loadIntrospection() async throws -> (String?, __Schema) {
        switch configuration.input.schemaSource {
        case .introspectionEndpoint(
            let endpoint,
            let includeDeprecatedFields,
            let includeDeprecatedEnumValues
        ):
            try await loadSchemaFromIntrospectionEndpoint(
                endpoint: endpoint,
                includeDeprecatedFields: includeDeprecatedFields,
                includeDeprecatedEnumValues: includeDeprecatedEnumValues
            )
        case .JSONSchemaFile(let schemaFile):
            try loadSchemaFromJSONFile(schemaFile)
        case .SDLSchemaFile(
            let schemaFile,
            let includeDeprecatedFields,
            let includeDeprecatedEnumValues
        ):
            try loadSchemaFromSDLFile(
                schemaFile,
                includeDeprecatedFields: includeDeprecatedFields,
                includeDeprecatedEnumValues: includeDeprecatedEnumValues
            )
        }
    }

    private func loadSchemaFromIntrospectionEndpoint(
        endpoint: URL,
        includeDeprecatedFields: Bool = false,
        includeDeprecatedEnumValues: Bool = false
    ) async throws -> (String?, __Schema) {
        let data = try await IntrospectionRunner(
            endpoint: endpoint,
            includeDeprecatedFields: includeDeprecatedFields,
            includeDeprecatedEnumValues: includeDeprecatedEnumValues,
            urlSession: .shared
        ).run()
        let __schema = try JSONDecoder().decode(IntrospectionResponse.self, from: data).data.__schema
        var schemaString: String?
        if configuration.validation {
            let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let schemaJSONData = try JSONSerialization.data(withJSONObject: obj["data"] as Any)
            schemaString = String(data: schemaJSONData, encoding: .utf8)!
        }
        return (schemaString, __schema)
    }

    private func loadSchemaFromJSONFile(_ schemaFile: URL) throws -> (String?, __Schema) {
        let data = try Data(contentsOf: schemaFile)
        let __schema = try JSONDecoder().decode(IntrospectionResponse.Data.self, from: data).__schema
        var schemaString: String?
        if configuration.validation {
            schemaString = String(data: data, encoding: .utf8)!
        }
        return (schemaString, __schema)
    }

    private func loadSchemaFromSDLFile(
        _ schemaFile: URL,
        includeDeprecatedFields: Bool,
        includeDeprecatedEnumValues: Bool
    ) throws -> (String?, __Schema) {
        let sdlSchemaString = try String(contentsOf: schemaFile, encoding: .utf8)
        let introspectionQuery = IntrospectionQuery(
            includeDeprecatedFields: includeDeprecatedFields,
            includeDeprecatedEnumValues: includeDeprecatedEnumValues
        ).query
        let jsonSchemaString = GraphQLJS.convertSDLSchema(
            sdlSchemaString,
            introspectionQuery: introspectionQuery
        )
        if jsonSchemaString == "undefined" {
            throw Codegen.Error(description: "Failed to parse schema SDL")
        }
        let data = Data(jsonSchemaString.utf8)
        if let error = try? JSONDecoder().decode(DocumentValidator.Error.self, from: data) {
            throw Codegen.Error(description: """
            Failed to parse schema SDL
            \(error.description)
            """)
        }
        let __schema = try JSONDecoder().decode(IntrospectionResponse.Data.self, from: data).__schema
        return (configuration.validation ? jsonSchemaString : nil, __schema)
    }
}
