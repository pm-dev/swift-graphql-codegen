import Foundation

struct URLSessionWriter {
    let configuration: Configuration

    private var accessLevel: String {
        configuration.output.api.accessLevel == .public ? "public " : ""
    }

    private var header: String {
        guard let header = configuration.output.api.header else { return "" }
        return "\(header)\n"
    }

    private var url: URL {
        configuration.output.api.directory.appending(
            path: "HTTPSupport/URLSession+GraphQL.swift",
            directoryHint: .notDirectory
        )
    }

    func write() async throws {
        try await content().write(to: url)
    }

    private func content() -> String {
        switch configuration.output.documents.operations.persistedOperations {
        case .automatic: AutomaticPersistedOperations()
        case .registered, .none: NoPersistedOperations()
        }
    }

    private func AutomaticPersistedOperations() -> String {
        """
        \(header)import Foundation

        /// Defaults conform to https://graphql.github.io/graphql-over-http/draft/
        extension URLSession {
            \(accessLevel)struct HTTPError: Error {
                \(accessLevel)let response: HTTPURLResponse
            }

            /// Executes a GraphQL operation
            /// - Parameters:
            ///   - request: The request containing the `URLRequest` to be performed.
            ///   - decoder: The function used to turn response data into an Operation.Data instance.
            \(accessLevel)func request<Operation: GraphQLOperation>(
                _ request: GraphQLRequest<Operation>,
                decoder: (Data) throws -> GraphQLResponse<Operation.Data> = GraphQLRequest<Operation>.defaultDecoder()
            ) async throws -> GraphQLResponse<Operation.Data>.Success {
                let (data, response) = try await data(for: request.urlRequest)
                if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                    throw HTTPError(response: httpResponse)
                }
                switch try decoder(data) {
                case .success(let success): return success
                case .requestError(let requestError):
                    let containsPersistedQueryNotFound = requestError.errors.contains { error in
                        error.message == "PersistedQueryNotFound"
                    }
                    if containsPersistedQueryNotFound,
                       let persistedOperationBodyEncoder = request.persistedOperationBodyEncoder {
                        return try await self.request(
                            try persistingRequest(request, bodyEncoder: persistedOperationBodyEncoder),
                            decoder: decoder
                        )
                    }
                    throw requestError
                }
            }

            private func persistingRequest<Operation: GraphQLOperation>(
                _ original: GraphQLRequest<Operation>,
                bodyEncoder: HTTPBodyEncoder
            ) throws -> GraphQLRequest<Operation> {
                var urlRequest = original.urlRequest
                urlRequest.url = original.endpoint
                urlRequest.httpBody = try bodyEncoder.encode(
                    operation: original.operation,
                    automaticPersistedOperationPhase: .persistRequestWithDocument,
                    minifyDocument: original.minifyDocument
                )
                return GraphQLRequest(
                    urlRequest: urlRequest,
                    endpoint: original.endpoint,
                    operation: original.operation,
                    minifyDocument: original.minifyDocument,
                    persistedOperationBodyEncoder: nil
                )
            }
        }

        """
    }

    private func NoPersistedOperations() -> String {
        """
        \(header)import Foundation

        /// Defaults conform to https://graphql.github.io/graphql-over-http/draft/
        extension URLSession {
            \(accessLevel)struct HTTPError: Error {
                \(accessLevel)let response: HTTPURLResponse
            }

            /// Executes a GraphQL operation
            /// - Parameters:
            ///   - request: The request containing the `URLRequest` to be performed.
            ///   - decoder: The function used to turn response data into an Operation.Data instance.
            \(accessLevel)func request<Operation: GraphQLOperation>(
                _ request: GraphQLRequest<Operation>,
                decoder: (Data) throws -> GraphQLResponse<Operation.Data> = GraphQLRequest<Operation>.defaultDecoder()
            ) async throws -> GraphQLResponse<Operation.Data>.Success {
                let (data, response) = try await data(for: request.urlRequest)
                if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                    throw HTTPError(response: httpResponse)
                }
                switch try decoder(data) {
                case .success(let success): return success
                case .requestError(let requestError): throw requestError
                }
            }
        }

        """
    }
}
