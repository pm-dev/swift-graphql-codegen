struct GraphQLResponseWriter: SupportOutput {
    let configuration: Configuration
    let requiresResponseDecodingContext: Bool

    var topLevelTypeNames: [SwiftTypeIdentifier] {
        var typeNames = [SwiftTypeIdentifier(swiftName: "GraphQLResponse")]
        if requiresResponseDecodingContext {
            typeNames.append(SwiftTypeIdentifier(swiftName: "GraphQLResponseDecodingContext"))
        }
        return typeNames
    }

    var source: String {
        responseDecodingContext() + """
        \(accessLevel)enum GraphQLResponse<Data>: Decodable where Data: Decodable, Data: Sendable {
            \(accessLevel)struct ExecutionResult: Sendable {
                \(accessLevel)let data: Data?
                \(accessLevel)let errors: [GraphQLError]?
                \(accessLevel)let extensions: [String: JSONValue]?
            }

            \(accessLevel)struct RequestError: Error, Sendable {
                \(accessLevel)let errors: [GraphQLError]
                \(accessLevel)let extensions: [String: JSONValue]?
            }

            case executionResult(ExecutionResult)
            case requestError(RequestError)

            private enum CodingKeys: String, CodingKey {
                case data
                case errors
                case extensions
            }

            \(accessLevel)init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let errors = try container.decodeIfPresent([GraphQLError].self, forKey: .errors)
                let extensions = try container.decodeIfPresent([String: JSONValue].self, forKey: .extensions)
                if container.contains(.data) {
                    let data = try container.decodeIfPresent(Data.self, forKey: .data)
                    guard errors?.isEmpty != true else {
                        throw DecodingError.dataCorruptedError(
                            forKey: .errors,
                            in: container,
                            debugDescription: \"\"\"
                            The errors entry in the response is a non-empty list of errors
                            https://spec.graphql.org/September2025/#sec-Execution-Result
                            \"\"\"
                        )
                    }
                    self = .executionResult(
                        GraphQLResponse<Data>.ExecutionResult(
                            data: data,
                            errors: errors,
                            extensions: extensions
                        )
                    )
                } else {
                    guard let errors, !errors.isEmpty else {
                        throw DecodingError.dataCorruptedError(
                            forKey: .errors,
                            in: container,
                            debugDescription: \"\"\"
                            If the data entry in the response is not present, the errors entry in the response must not be empty
                            https://spec.graphql.org/September2025/#sec-Request-Error-Result
                            \"\"\"
                        )
                    }
                    self = .requestError(RequestError(errors: errors, extensions: extensions))
                }
            }
        }
        """
    }

    private func responseDecodingContext() -> String {
        guard requiresResponseDecodingContext else { return "" }
        return """
        /// Carries the effective Boolean operation variables needed to decode conditional fragment spreads.
        \(accessLevel)struct GraphQLResponseDecodingContext: Sendable {
            \(accessLevel)let directiveVariables: [String: Bool]

            @TaskLocal
            private static var ancestorTypenames: [String?] = []

            /// Creates a context from effective directive values, including applied operation defaults.
            \(accessLevel)init(directiveVariables: [String: Bool]) {
                self.directiveVariables = directiveVariables
            }

            static func withAncestorTypename<Value>(
                _ typename: String?,
                _ decode: () throws -> Value
            ) rethrows -> Value {
                try $ancestorTypenames.withValue(ancestorTypenames + [typename], operation: decode)
            }

            static func ancestorTypename(levelsUp: Int) -> String? {
                let ancestors = ancestorTypenames
                let index = ancestors.count - levelsUp
                guard ancestors.indices.contains(index) else { return nil }
                return ancestors[index]
            }
        }

        extension CodingUserInfoKey {
            /// Makes the operation's directive variables available throughout nested response decoding.
            \(accessLevel)static let graphQLResponseDecodingContext = CodingUserInfoKey(
                rawValue: "GraphQLResponseDecodingContext"
            )!
        }


        """
    }
}
