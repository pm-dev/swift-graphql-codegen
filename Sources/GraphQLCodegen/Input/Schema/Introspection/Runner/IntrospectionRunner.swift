import Foundation

struct IntrospectionRunner {
    let endpoint: URL
    let headers: [String: String]
    let includeDeprecated: Bool
    let urlSession: URLSession

    func run() async throws -> Data {
        let urlRequest = try request()
        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse else {
            throw Codegen.Error(description: "The introspection endpoint did not return an HTTP response.")
        }
        guard (200..<300).contains(response.statusCode) else {
            throw Codegen.Error(description: """
            The introspection endpoint returned HTTP \(response.statusCode).
            \(endpoint)
            """)
        }
        return data
    }

    func request() throws -> URLRequest {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.setValue("application/graphql-response+json", forHTTPHeaderField: "accept")
        for (field, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }
        urlRequest.httpBody = try JSONEncoder().encode(
            IntrospectionQuery(includeDeprecated: includeDeprecated)
        )
        return urlRequest
    }
}
