import Foundation
@preconcurrency import JavaScriptCore

struct GraphQLJS {
    enum Error: Swift.Error, CustomStringConvertible {
        case bundleEvaluationFailed(String)
        case bundleReadFailed(URL, String)
        case bundleResourceMissing
        case contextCreationFailed
        case inputRejected(function: String, message: String)
        case invocationFailed(function: String, message: String)
        case missingExport(String)
        case unexpectedResult(function: String, expected: String)

        var description: String {
            switch self {
            case .bundleEvaluationFailed(let message):
                "Failed to evaluate the bundled GraphQL JavaScript: \(message)"
            case .bundleReadFailed(let url, let message):
                "Failed to read the bundled GraphQL JavaScript at \(url.path): \(message)"
            case .bundleResourceMissing:
                "The bundled GraphQL JavaScript resource is missing."
            case .contextCreationFailed:
                "Failed to create a JavaScript context for GraphQL."
            case .inputRejected(let function, let message):
                "GraphQL input was rejected by \(function): \(message)"
            case .invocationFailed(let function, let message):
                "The GraphQL JavaScript function \(function) failed: \(message)"
            case .missingExport(let name):
                "The bundled GraphQL JavaScript does not export \(name)."
            case .unexpectedResult(let function, let expected):
                "The GraphQL JavaScript function \(function) did not return \(expected)."
            }
        }
    }

    let sourceText: String

    private let context: JSContext
    private let library: JSValue

    init(sourceText: String) throws {
        guard let libraryURL = Bundle.module.url(forResource: "graphql.bundle", withExtension: "js") else {
            throw Error.bundleResourceMissing
        }
        let libraryContents: String
        do {
            libraryContents = try String(contentsOf: libraryURL, encoding: .utf8)
        } catch {
            throw Error.bundleReadFailed(libraryURL, String(describing: error))
        }
        guard let context = JSContext() else {
            throw Error.contextCreationFailed
        }
        context.evaluateScript(libraryContents)
        if let exception = context.exception {
            throw Error.bundleEvaluationFailed(exception.toString() ?? "Unknown JavaScript exception")
        }
        guard let library = context.objectForKeyedSubscript("GraphQL"),
              library.isObject,
              !library.isNull,
              !library.isUndefined else {
            throw Error.missingExport("GraphQL")
        }
        self.context = context
        self.library = library
        self.sourceText = sourceText
    }

    func canonicalized() throws -> String {
        try stringResult(function: "canonicalizeDocument", arguments: [sourceText])
    }

    func convertedSDLSchema(introspectionQuery: String) throws -> Data {
        Data(
            try stringResult(
                function: "convertSDLSchema",
                arguments: [sourceText, introspectionQuery]
            ).utf8
        )
    }

    func parsed() throws -> Data {
        Data(try stringResult(function: "parseGraphQL", arguments: [sourceText]).utf8)
    }

    func validated(schemaJSONString: String) throws -> Data {
        Data(
            try stringResult(
                function: "validateDocument",
                arguments: [sourceText, schemaJSONString]
            ).utf8
        )
    }

    private func stringResult(function name: String, arguments: [Any]) throws -> String {
        guard let function = library.objectForKeyedSubscript(name),
              function.isObject,
              !function.isNull,
              !function.isUndefined else {
            throw Error.missingExport(name)
        }
        context.exception = nil
        let result = function.call(withArguments: arguments)
        if let exception = context.exception {
            throw Error.invocationFailed(
                function: name,
                message: exception.toString() ?? "Unknown JavaScript exception"
            )
        }
        guard let result, result.isObject else {
            throw Error.unexpectedResult(function: name, expected: "an outcome object")
        }
        guard let statusValue = result.objectForKeyedSubscript("status"),
              statusValue.isString,
              let status = statusValue.toString() else {
            throw Error.unexpectedResult(function: name, expected: "an outcome status")
        }
        switch status {
        case "success":
            guard let value = result.objectForKeyedSubscript("value"),
                  value.isString,
                  let string = value.toString() else {
                throw Error.unexpectedResult(function: name, expected: "a string value")
            }
            return string
        case "invalidInput":
            guard let messageValue = result.objectForKeyedSubscript("message"),
                  messageValue.isString,
                  let message = messageValue.toString() else {
                throw Error.unexpectedResult(function: name, expected: "an input error message")
            }
            throw Error.inputRejected(function: name, message: message)
        default:
            throw Error.unexpectedResult(function: name, expected: "a recognized outcome status")
        }
    }
}
