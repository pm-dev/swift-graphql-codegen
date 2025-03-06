struct GraphQLResponseWriter {
    let configuration: Configuration

    private var accessLevel: String {
        configuration.output.api.accessLevel == .public ? "public " : ""
    }

    private var header: String {
        guard let header = configuration.output.api.header else { return "" }
        return "\(header)\n\n"
    }

    func write() async throws {
        try await """
        \(header)\(accessLevel)enum GraphQLResponse<Data>: Decodable where Data: Decodable, Data: Sendable {
            \(accessLevel)struct Success: Sendable {
                \(accessLevel)let data: Data
                \(accessLevel)let fieldErrors: [GraphQLError]?
                \(accessLevel)let extensions: [String: JSONValue]?
            }

            \(accessLevel)struct RequestError: Error, Sendable {
                \(accessLevel)let errors: [GraphQLError]
                \(accessLevel)let extensions: [String: JSONValue]?
            }

            case success(Success)
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
                if let data = try container.decodeIfPresent(Data.self, forKey: .data) {
                    guard errors == nil || !errors!.isEmpty else {
                        throw DecodingError.dataCorruptedError(
                            forKey: .errors,
                            in: container,
                            debugDescription: \"\"\"
                            The errors entry in the response is a non-empty list of errors
                            https://spec.graphql.org/October2021/#sel-FAPHRDCAACC0B59K
                            \"\"\"
                        )
                    }
                    self = .success(
                        GraphQLResponse<Data>.Success(
                            data: data,
                            fieldErrors: errors,
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
                            https://spec.graphql.org/October2021/#sel-FAPHRHCAACEoBpjW
                            \"\"\"
                        )
                    }
                    self = .requestError(RequestError(errors: errors, extensions: extensions))
                }
            }
        }
        """.write(
            to: configuration.output.api.directory.appending(
                path: "GraphQLResponse.swift",
                directoryHint: .notDirectory
            )
        )
    }
}
