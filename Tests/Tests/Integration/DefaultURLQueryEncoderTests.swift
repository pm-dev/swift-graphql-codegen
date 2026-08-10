import CryptoKit
@testable import Fixtures
import Foundation
import Testing

struct DefaultURLQueryEncoderTests {
    @Test
    func persistedHashUsesDocument() throws {
        let queryItems = try DefaultURLQueryEncoder().encode(
            operation: DescribedQuery(),
            automaticPersistedOperationPhase: .initialRequestWithHash
        )
        let extensionsValue = try #require(queryItems.first { $0.name == "extensions" }?.value)
        let extensions = try JSONDecoder().decode(
            PersistedExtensions.self,
            from: Data(extensionsValue.utf8)
        )

        #expect(extensions.persistedQuery.sha256Hash == hash(DescribedQuery.document))
    }

    @Test
    func omitsDocumentFromPersistedQuery() throws {
        let queryItems = try DefaultURLQueryEncoder().encode(
            operation: CurrentUserQuery(),
            automaticPersistedOperationPhase: .initialRequestWithHash
        )

        #expect(queryItems.map(\.name) == ["operationName", "extensions"])
        #expect(queryItems.allSatisfy { $0.value != nil })
    }

    @Test
    func includesDocumentInStandardQuery() throws {
        let queryItems = try DefaultURLQueryEncoder().encode(
            operation: CurrentUserQuery(),
            automaticPersistedOperationPhase: nil
        )

        #expect(queryItems.map(\.name) == ["operationName", "query"])
        #expect(queryItems.allSatisfy { $0.value != nil })
        #expect(queryItems.first { $0.name == "query" }?.value == CurrentUserQuery.document)
    }

    @Test
    func omitsAbsentOperationName() throws {
        let queryItems = try DefaultURLQueryEncoder().encode(
            operation: AnonymousQuery(),
            automaticPersistedOperationPhase: nil
        )

        #expect(queryItems.map(\.name) == ["query"])
    }

    @Test
    func encodesPresentVariablesAndExtensionsAsJSONMaps() throws {
        let queryItems = try DefaultURLQueryEncoder().encode(
            operation: ParameterizedQuery(),
            automaticPersistedOperationPhase: nil
        )

        #expect(queryItems.map(\.name) == ["operationName", "query", "variables", "extensions"])

        let variablesValue = try #require(queryItems.first { $0.name == "variables" }?.value)
        let variablesData = try #require(variablesValue.data(using: .utf8))
        let variables = try JSONDecoder().decode(EncodedVariables.self, from: variablesData)
        #expect(variables.includeDetails)

        let extensionsValue = try #require(queryItems.first { $0.name == "extensions" }?.value)
        let extensionsData = try #require(extensionsValue.data(using: .utf8))
        let extensions = try JSONDecoder().decode(EncodedExtensions.self, from: extensionsData)
        #expect(extensions.requestID == "request-id")
    }

    private struct AnonymousQuery: GraphQLQuery {
        struct Data: Decodable, Sendable {}

        static let operationName: String? = nil
        static let document = "{viewer{id}}"

        let variables: Never? = nil
        let extensions: [String: Fixtures.AnyEncodable]? = nil
    }

    private struct CurrentUserQuery: GraphQLQuery {
        struct Data: Decodable, Sendable {}

        static let operationName: String? = "CurrentUser"
        static let document = "query CurrentUser{viewer{id}}"

        let variables: Never? = nil
        let extensions: [String: Fixtures.AnyEncodable]? = nil
    }

    private struct DescribedQuery: GraphQLQuery {
        struct Data: Decodable, Sendable {}

        static let operationName: String? = "Described"
        static let document = "query Described{viewer{id}}"

        let variables: Never? = nil
        let extensions: [String: Fixtures.AnyEncodable]? = nil
    }

    private struct EncodedExtensions: Decodable {
        let requestID: String
    }

    private struct EncodedVariables: Decodable {
        let includeDetails: Bool
    }

    private struct ParameterizedQuery: GraphQLQuery {
        struct Data: Decodable, Sendable {}

        static let operationName: String? = "Parameterized"
        static let document = "query Parameterized($includeDetails:Boolean!){viewer{id}}"

        let variables = Variables(includeDetails: true)
        let extensions: [String: Fixtures.AnyEncodable]? = [
            "requestID": Fixtures.AnyEncodable("request-id")
        ]

        struct Variables: Encodable, Sendable {
            // periphery:ignore - Used through the synthesized Encodable implementation.
            let includeDetails: Bool
        }
    }

    private struct PersistedExtensions: Decodable {
        struct PersistedQuery: Decodable {
            let sha256Hash: String
        }

        let persistedQuery: PersistedQuery
    }

    private func hash(_ document: String) -> String {
        SHA256.hash(data: Data(document.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
