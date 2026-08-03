@preconcurrency import JavaScriptCore

struct GraphQLJS {
    let sourceText: String

    private var parseGraphQLFunction: JSValue { library.objectForKeyedSubscript("parseGraphQL") }

    private var validateDocumentFunction: JSValue { library.objectForKeyedSubscript("validateDocument") }

    private var convertSDLSchemaFunction: JSValue { library.objectForKeyedSubscript("convertSDLSchema") }

    private var canonicalizeDocumentFunction: JSValue {
        library.objectForKeyedSubscript("canonicalizeDocument")
    }

    private static let graphqlJSLibContents: String = {
        let graphqlJSLibFileURL = Bundle.module.url(forResource: "graphql.bundle", withExtension: "js")!
        return try! String(contentsOf: graphqlJSLibFileURL, encoding: .utf8)
    }()

    private var library: JSValue {
        let context = JSContext()!
        context.evaluateScript(Self.graphqlJSLibContents)
        return context.objectForKeyedSubscript("GraphQL")!
    }

    func parsed() -> String {
        let javascriptResult: JSValue = parseGraphQLFunction.call(withArguments: [sourceText])
        return javascriptResult.toString()
    }

    func validated(schemaJSONString: String) -> String {
        let javascriptResult: JSValue = validateDocumentFunction.call(
            withArguments: [
                sourceText,
                schemaJSONString,
            ]
        )
        return javascriptResult.toString()
    }

    func convertedSDLSchema(introspectionQuery: String) -> String {
        let javascriptResult: JSValue = convertSDLSchemaFunction.call(
            withArguments: [
                sourceText,
                introspectionQuery,
            ]
        )
        return javascriptResult.toString()
    }

    func canonicalized() -> String {
        canonicalizeDocumentFunction.call(withArguments: [sourceText]).toString()
    }
}
