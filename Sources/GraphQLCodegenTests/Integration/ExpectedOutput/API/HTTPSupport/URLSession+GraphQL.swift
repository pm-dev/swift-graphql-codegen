// @generated
import Foundation

/// Defaults conform to https://graphql.github.io/graphql-over-http/draft/
extension URLSession {
    struct HTTPError: Error {
        let response: HTTPURLResponse
    }

    /// Executes a GraphQL operation
    /// - Parameters:
    ///   - request: The request containing the `URLRequest` to be performed.
    ///   - decoder: The function used to turn response data into an Operation.Data instance.
    func request<Operation: GraphQLOperation>(
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
