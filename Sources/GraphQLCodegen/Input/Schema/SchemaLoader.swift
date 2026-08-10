import Foundation

struct LoadedSchema {
    let schema: Schema
    let schemaJSON: String
}

private struct LoadedIntrospection {
    let schema: __Schema
    let schemaJSON: String
}

// Type names are guaranteed to be unique
// https://spec.graphql.org/September2025/#sel-DAHTCKBDLA5BotN
struct TypeASTCache {
    var scalars: [String: __Schema.__NamedType.Scalar] = [:]
    var objects: [String: __Schema.__NamedType.Object] = [:]
    var interfaces: [String: __Schema.__NamedType.Interface] = [:]
    var unions: [String: __Schema.__NamedType.Union] = [:]
    var enums: [String: __Schema.__NamedType.Enum] = [:]
    var inputObjects: [String: __Schema.__NamedType.InputObject] = [:]
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
        let introspection = try await loadIntrospection()
        let projectedSchema = introspection.schema.applying(configuration.input.deprecationPolicy)
        return LoadedSchema(
            schema: Schema(
                queryTypeRef: projectedSchema.queryType,
                mutationTypeRef: projectedSchema.mutationType,
                subscriptionTypeRef: projectedSchema.subscriptionType,
                typeCache: TypeCache(TypeASTCache(projectedSchema))
            ),
            schemaJSON: introspection.schemaJSON
        )
    }

    private func loadIntrospection() async throws -> LoadedIntrospection {
        switch configuration.input.schemaSource {
        case .introspectionEndpoint(
            let endpoint,
            let headers
        ):
            try await loadSchemaFromIntrospectionEndpoint(
                endpoint: endpoint,
                headers: headers
            )
        case .file(.introspectionJSON(let schemaFile)):
            try loadSchemaFromJSONFile(schemaFile)
        case .file(.SDL(let schemaFile)):
            try loadSchemaFromSDLFile(schemaFile)
        }
    }

    private func loadSchemaFromIntrospectionEndpoint(
        endpoint: URL,
        headers: [String: String]
    ) async throws -> LoadedIntrospection {
        let data = try await IntrospectionRunner(
            endpoint: endpoint,
            headers: headers,
            urlSession: urlSession
        ).run()
        let __schema = try JSONDecoder().decode(IntrospectionResponse.self, from: data).data.__schema
        guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let schemaObject = response["data"] else {
            throw Codegen.Error(description: "The introspection endpoint returned an invalid GraphQL response.")
        }
        let schemaJSON = try JSONSerialization.data(withJSONObject: schemaObject)
        return LoadedIntrospection(
            schema: __schema,
            schemaJSON: try decodeUTF8(schemaJSON, source: endpoint)
        )
    }

    private func loadSchemaFromJSONFile(_ schemaFile: URL) throws -> LoadedIntrospection {
        let data = try Data(contentsOf: schemaFile)
        let __schema = try JSONDecoder().decode(IntrospectionResponse.Data.self, from: data).__schema
        return LoadedIntrospection(
            schema: __schema,
            schemaJSON: try decodeUTF8(data, source: schemaFile)
        )
    }

    private func loadSchemaFromSDLFile(_ schemaFile: URL) throws -> LoadedIntrospection {
        let sdlSchemaString = try String(contentsOf: schemaFile, encoding: .utf8)
        let introspectionQuery = IntrospectionQuery().query
        let jsonSchema = try graphQLJS.convertSDLSchema(
            sdlSchemaString,
            introspectionQuery: introspectionQuery
        )
        let __schema = try JSONDecoder().decode(IntrospectionResponse.Data.self, from: jsonSchema.data).__schema
        return LoadedIntrospection(
            schema: __schema,
            schemaJSON: jsonSchema.text
        )
    }

    private func decodeUTF8(_ data: Data, source: URL) throws -> String {
        guard let string = String(data: data, encoding: .utf8) else {
            throw Codegen.Error(description: "Schema source is not valid UTF-8: \(source)")
        }
        return string
    }
}
