@preconcurrency import JavaScriptCore

enum GraphQLJS {
    private static var parseGraphQLFunction: JSValue { library.objectForKeyedSubscript("parseGraphQL") }

    private static var validateDocumentFunction: JSValue { library.objectForKeyedSubscript("validateDocument") }

    private static var convertSDLSchemaFunction: JSValue { library.objectForKeyedSubscript("convertSDLSchema") }

    private static let graphqlJSLibContents: String = {
        let graphqlJSLibFileURL = Bundle.module.url(forResource: "graphql.bundle", withExtension: "js")!
        return try! String(contentsOf: graphqlJSLibFileURL, encoding: .utf8)
    }()

    private static var library: JSValue {
        let context = JSContext()!
        context.evaluateScript(graphqlJSLibContents)
        return context.objectForKeyedSubscript("GraphQL")!
    }

    static func parseGraphQL(_ sourceText: String) -> String {
        let javascriptResult: JSValue = parseGraphQLFunction.call(withArguments: [sourceText])
        return javascriptResult.toString()
    }

    static func validateDocument(_ documentText: String, schemaJSONString: String) -> String {
        let javascriptResult: JSValue = validateDocumentFunction.call(
            withArguments: [
                documentText,
                schemaJSONString,
            ]
        )
        return javascriptResult.toString()
    }

    static func convertSDLSchema(_ sdlSchemaString: String, introspectionQuery: String) -> String {
        let javascriptResult: JSValue = convertSDLSchemaFunction.call(
            withArguments: [
                sdlSchemaString,
                introspectionQuery,
            ]
        )
        return javascriptResult.toString()
    }
}
