import Foundation

struct LoadedSchema {
    enum Validation {
        case disabled
        case enabled(String)
    }

    let schema: Schema
    let validation: Validation
}

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
            }
        }
    }

    func inheritedInterfaces(_ directInterfaces: [__Schema.__TypeRef.Interface]) -> Set<String> {
        var inherited: Set<String> = []
        var remaining = directInterfaces.map(\.name)
        while let name = remaining.popLast() {
            guard inherited.insert(name).inserted,
                  let interface = interfaces[name] else {
                continue
            }
            remaining.append(contentsOf: interface.interfaces.map(\.name))
        }
        return inherited
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
            objects[name] = Schema.Object(
                ast: ast,
                fields: ast.fields.reduce(into: [:]) { fields, field in fields[field.name] = field },
                implements: cache.inheritedInterfaces(ast.interfaces)
            )
        }
        for (name, ast) in cache.interfaces {
            interfaces[name] = Schema.Interface(
                ast: ast,
                fields: ast.fields.reduce(into: [:]) { fields, field in fields[field.name] = field },
                implements: cache.inheritedInterfaces(ast.interfaces)
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
    let graphQLJS: GraphQLJS
    let urlSession: URLSession

    func load() async throws -> LoadedSchema {
        let (validation, typedSchema) = try await loadIntrospection()
        return LoadedSchema(
            schema: Schema(
                queryTypeRef: typedSchema.queryType,
                mutationTypeRef: typedSchema.mutationType,
                subscriptionTypeRef: typedSchema.subscriptionType,
                typeCache: TypeCache(TypeASTCache(typedSchema))
            ),
            validation: validation
        )
    }

    private func loadIntrospection() async throws -> (LoadedSchema.Validation, __Schema) {
        switch configuration.input.schemaSource {
        case .introspectionEndpoint(
            let endpoint,
            let headers,
            let includeDeprecatedFields,
            let includeDeprecatedEnumValues
        ):
            try await loadSchemaFromIntrospectionEndpoint(
                endpoint: endpoint,
                headers: headers,
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
        headers: [String: String],
        includeDeprecatedFields: Bool = false,
        includeDeprecatedEnumValues: Bool = false
    ) async throws -> (LoadedSchema.Validation, __Schema) {
        let data = try await IntrospectionRunner(
            endpoint: endpoint,
            headers: headers,
            includeDeprecatedFields: includeDeprecatedFields,
            includeDeprecatedEnumValues: includeDeprecatedEnumValues,
            urlSession: urlSession
        ).run()
        let __schema = try JSONDecoder().decode(IntrospectionResponse.self, from: data).data.__schema
        guard configuration.validation else { return (.disabled, __schema) }
        guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let schemaObject = response["data"] else {
            throw Codegen.Error(description: "The introspection endpoint returned an invalid GraphQL response.")
        }
        let schemaJSON = try JSONSerialization.data(withJSONObject: schemaObject)
        return (.enabled(try decodeUTF8(schemaJSON, source: endpoint)), __schema)
    }

    private func loadSchemaFromJSONFile(_ schemaFile: URL) throws -> (LoadedSchema.Validation, __Schema) {
        let data = try Data(contentsOf: schemaFile)
        let __schema = try JSONDecoder().decode(IntrospectionResponse.Data.self, from: data).__schema
        guard configuration.validation else { return (.disabled, __schema) }
        return (.enabled(try decodeUTF8(data, source: schemaFile)), __schema)
    }

    private func loadSchemaFromSDLFile(
        _ schemaFile: URL,
        includeDeprecatedFields: Bool,
        includeDeprecatedEnumValues: Bool
    ) throws -> (LoadedSchema.Validation, __Schema) {
        let sdlSchemaString = try String(contentsOf: schemaFile, encoding: .utf8)
        let introspectionQuery = IntrospectionQuery(
            includeDeprecatedFields: includeDeprecatedFields,
            includeDeprecatedEnumValues: includeDeprecatedEnumValues
        ).query
        let jsonSchema = try graphQLJS.convertSDLSchema(
            sdlSchemaString,
            introspectionQuery: introspectionQuery
        )
        let __schema = try JSONDecoder().decode(IntrospectionResponse.Data.self, from: jsonSchema.data).__schema
        guard configuration.validation else { return (.disabled, __schema) }
        return (.enabled(jsonSchema.text), __schema)
    }

    private func decodeUTF8(_ data: Data, source: URL) throws -> String {
        guard let string = String(data: data, encoding: .utf8) else {
            throw Codegen.Error(description: "Schema source is not valid UTF-8: \(source)")
        }
        return string
    }
}
