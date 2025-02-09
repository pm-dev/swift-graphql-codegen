import Foundation

struct IntrospectionRunner {
    let endpoint: URL
    let includeDeprecatedFields: Bool
    let includeDeprecatedEnumValues: Bool
    let urlSession: URLSession

    func run() async throws -> Data {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.setValue("application/graphql-response+json", forHTTPHeaderField: "accept")
        urlRequest.httpBody = try JSONEncoder().encode(
            IntrospectionQuery(
                includeDeprecatedFields: includeDeprecatedFields,
                includeDeprecatedEnumValues: includeDeprecatedEnumValues
            )
        )
        let (data, _) = try await urlSession.data(for: urlRequest)
        return data
    }
}
