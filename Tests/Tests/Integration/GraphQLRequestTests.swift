import Foundation
import Testing
@testable import Fixtures

struct GraphQLRequestTests {
    private final class TrackingHTTPBodyEncoder: HTTPBodyEncoder {
        let contentType = "application/json"
        private(set) var initialRequestCount = 0
        private(set) var persistRequestCount = 0

        func encode<Operation: GraphQLOperation>(
            operation: Operation,
            automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?
        ) throws -> Data {
            switch automaticPersistedOperationPhase {
            case .some(.initialRequestWithHash): initialRequestCount += 1
            case .some(.persistRequestWithDocument): persistRequestCount += 1
            case nil: break
            }
            return try JSONBodyEncoder().encode(
                operation: operation,
                automaticPersistedOperationPhase: automaticPersistedOperationPhase
            )
        }
    }

    private final class TrackingURLQueryEncoder: URLQueryEncoder {
        private(set) var encodeCount = 0

        func encode<Operation: GraphQLOperation>(
            operation: Operation,
            automaticPersistedOperationPhase: AutomaticPersistedOperationPhase?
        ) throws -> [URLQueryItem] {
            encodeCount += 1
            return try DefaultURLQueryEncoder().encode(
                operation: operation,
                automaticPersistedOperationPhase: automaticPersistedOperationPhase
            )
        }
    }

    private struct EncodedExtensions: Decodable {
        struct PersistedQuery: Decodable {
            let sha256Hash: String
            let version: Int
        }

        let persistedQuery: PersistedQuery
    }

    private struct EncodedDocument: Decodable {
        let query: String?
    }

    private struct EncodedRequest: Decodable {
        struct Variables: Decodable {
            let state: String
        }

        let extensions: EncodedExtensions
        let operationName: String?
        let query: String?
        let variables: Variables
    }

    private let endpoint = URL(string: "https://example.com/graphql")!
    private let operation = NodeQuery(state: .stopped)

    @Test
    func convertedEnumCasesPreserveGraphQLWireValues() throws {
        #expect(State.ready.rawValue == "READY")
        let decoded = try JSONDecoder().decode(GraphQLEnum<State>.self, from: Data(#""READY""#.utf8))
        #expect(decoded == .known(.ready))
    }

    @Test
    func compiledFixtureSupportsMutationAndSubscriptionRequests() throws {
        let mutationRequest = try GraphQLRequest(
            operation: SetStateMutation(state: .stopped),
            endpoint: endpoint
        )
        #expect(mutationRequest.urlRequest.httpMethod == "POST")
        #expect(mutationRequest.persistedOperationRetry != nil)

        let subscriptionRequest = try GraphQLRequest(
            subscription: StateChangedSubscription(),
            endpoint: endpoint
        )
        #expect(subscriptionRequest.urlRequest.httpMethod == "GET")
        #expect(subscriptionRequest.urlRequest.value(forHTTPHeaderField: "accept") == "text/event-stream")
        #expect(subscriptionRequest.persistedOperationRetry == nil)

        let url = try #require(subscriptionRequest.urlRequest.url)
        let queryItems = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(
            queryItems.first { $0.name == "query" }?.value
                == StateChangedSubscription.document
        )

        let postSubscriptionRequest = try GraphQLRequest(
            subscription: StateChangedSubscription(),
            endpoint: endpoint,
            strategy: .POST()
        )
        #expect(postSubscriptionRequest.urlRequest.httpMethod == "POST")
        #expect(postSubscriptionRequest.persistedOperationRetry == nil)
        let body = try JSONDecoder().decode(
            EncodedDocument.self,
            from: #require(postSubscriptionRequest.urlRequest.httpBody)
        )
        #expect(body.query == StateChangedSubscription.document)
    }

    @Test
    func automaticPersistedOperationDefersGETRetryEncoding() throws {
        let retryEncoder = TrackingURLQueryEncoder()
        let request = try GraphQLRequest(
            query: operation,
            endpoint: endpoint,
            strategy: .GETWithAutomaticPersistedOperations(
                retryPolicy: .GET(queryEncoder: retryEncoder)
            )
        )

        #expect(retryEncoder.encodeCount == 0)
        let retry = try #require(request.persistedOperationRetry)
        _ = try request.updated(for: retry)
        #expect(retryEncoder.encodeCount == 1)
    }

    @Test
    func automaticPersistedOperationRetriesWithGET() throws {
        var request = try GraphQLRequest(
            query: operation,
            endpoint: endpoint,
            strategy: .GETWithAutomaticPersistedOperations(retryPolicy: .GET())
        )
        request.urlRequest.setValue("Bearer token", forHTTPHeaderField: "authorization")

        let retry = try #require(request.persistedOperationRetry)
        let updatedRequest = try request.updated(for: retry)
        let urlRequest = updatedRequest.urlRequest

        #expect(updatedRequest.persistedOperationRetry == nil)
        #expect(urlRequest.httpMethod == "GET")
        #expect(urlRequest.httpBody == nil)
        #expect(urlRequest.value(forHTTPHeaderField: "content-type") == nil)
        #expect(urlRequest.value(forHTTPHeaderField: "authorization") == "Bearer token")

        let url = try #require(urlRequest.url)
        let queryItems = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(queryItems.first { $0.name == "operationName" }?.value == "Node")
        #expect(queryItems.first { $0.name == "query" }?.value == NodeQuery.document)

        let variablesData = try #require(queryItems.first { $0.name == "variables" }?.value?.data(using: .utf8))
        let variables = try JSONDecoder().decode(EncodedRequest.Variables.self, from: variablesData)
        #expect(variables.state == "STOPPED")

        let extensionsData = try #require(queryItems.first { $0.name == "extensions" }?.value?.data(using: .utf8))
        let extensions = try JSONDecoder().decode(EncodedExtensions.self, from: extensionsData)
        #expect(extensions.persistedQuery.version == 1)
        #expect(extensions.persistedQuery.sha256Hash.count == 64)
    }

    @Test
    func automaticPersistedOperationDefaultsToPOSTRetry() throws {
        var request = try GraphQLRequest(
            query: operation,
            endpoint: endpoint,
            strategy: .GETWithAutomaticPersistedOperations()
        )
        request.urlRequest.setValue("Bearer token", forHTTPHeaderField: "authorization")

        let retry = try #require(request.persistedOperationRetry)
        let updatedRequest = try request.updated(for: retry)
        let urlRequest = updatedRequest.urlRequest

        #expect(updatedRequest.persistedOperationRetry == nil)
        #expect(urlRequest.url == endpoint)
        #expect(urlRequest.httpMethod == "POST")
        #expect(urlRequest.value(forHTTPHeaderField: "content-type") == "application/json")
        #expect(urlRequest.value(forHTTPHeaderField: "authorization") == "Bearer token")

        let body = try JSONDecoder().decode(EncodedRequest.self, from: #require(urlRequest.httpBody))
        #expect(body.operationName == "Node")
        #expect(body.query == NodeQuery.document)
        #expect(body.variables.state == "STOPPED")
        #expect(body.extensions.persistedQuery.version == 1)
        #expect(body.extensions.persistedQuery.sha256Hash.count == 64)
    }

    @Test
    func automaticPersistedOperationCanStartWithPOSTAndRetryWithGET() throws {
        let request = try GraphQLRequest(
            query: operation,
            endpoint: endpoint,
            strategy: .POSTWithAutomaticPersistedOperations(retryPolicy: .GET())
        )

        #expect(request.urlRequest.httpMethod == "POST")
        let retry = try #require(request.persistedOperationRetry)
        let updatedRequest = try request.updated(for: retry)
        let urlRequest = updatedRequest.urlRequest

        #expect(updatedRequest.persistedOperationRetry == nil)
        #expect(urlRequest.httpMethod == "GET")
        #expect(urlRequest.httpBody == nil)
        let url = try #require(urlRequest.url)
        let queryItems = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(queryItems.first { $0.name == "query" }?.value == NodeQuery.document)
    }

    @Test
    func automaticPersistedOperationUsesExplicitPOSTRetryEncoder() throws {
        let initialEncoder = TrackingHTTPBodyEncoder()
        let retryEncoder = TrackingHTTPBodyEncoder()
        let request = try GraphQLRequest(
            query: operation,
            endpoint: endpoint,
            strategy: .POSTWithAutomaticPersistedOperations(
                bodyEncoder: initialEncoder,
                retryPolicy: .POST(bodyEncoder: retryEncoder)
            )
        )

        #expect(initialEncoder.initialRequestCount == 1)
        #expect(initialEncoder.persistRequestCount == 0)
        #expect(retryEncoder.initialRequestCount == 0)
        #expect(retryEncoder.persistRequestCount == 0)

        let retry = try #require(request.persistedOperationRetry)
        _ = try request.updated(for: retry)

        #expect(initialEncoder.persistRequestCount == 0)
        #expect(retryEncoder.persistRequestCount == 1)
    }
}
