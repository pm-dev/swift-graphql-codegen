// @generated

public enum GraphQLResponse<Data>: Decodable where Data: Decodable, Data: Sendable {
    public struct ExecutionResult: Sendable {
        public let data: Data?
        public let errors: [GraphQLError]?
        public let extensions: [String: JSONValue]?
    }

    public struct RequestError: Error, Sendable {
        public let errors: [GraphQLError]
        public let extensions: [String: JSONValue]?
    }

    case executionResult(ExecutionResult)
    case requestError(RequestError)

    private enum CodingKeys: String, CodingKey {
        case data
        case errors
        case extensions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let errors = try container.decodeIfPresent([GraphQLError].self, forKey: .errors)
        let extensions = try container.decodeIfPresent([String: JSONValue].self, forKey: .extensions)
        if container.contains(.data) {
            let data = try container.decodeIfPresent(Data.self, forKey: .data)
            guard errors?.isEmpty != true else {
                throw DecodingError.dataCorruptedError(
                    forKey: .errors,
                    in: container,
                    debugDescription: """
                    The errors entry in the response is a non-empty list of errors
                    https://spec.graphql.org/September2025/#sec-Execution-Result
                    """
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
                    debugDescription: """
                    If the data entry in the response is not present, the errors entry in the response must not be empty
                    https://spec.graphql.org/September2025/#sec-Request-Error-Result
                    """
                )
            }
            self = .requestError(RequestError(errors: errors, extensions: extensions))
        }
    }
}