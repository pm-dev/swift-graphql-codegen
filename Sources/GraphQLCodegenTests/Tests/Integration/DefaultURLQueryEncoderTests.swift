import Foundation
@testable import StarwarsExample
import Testing

struct DefaultURLQueryEncoderTests {
    @Test
    func omitsDocumentFromPersistedQuery() throws {
        let queryItems = try DefaultURLQueryEncoder().encode(
            query: CurrentUserQuery(),
            automaticPersistedOperations: true,
            minifyDocument: true
        )

        #expect(queryItems.map(\.name) == ["operationName", "variables", "extensions"])
    }

    @Test
    func includesDocumentInStandardQuery() throws {
        let queryItems = try DefaultURLQueryEncoder().encode(
            query: CurrentUserQuery(),
            automaticPersistedOperations: false,
            minifyDocument: true
        )

        #expect(queryItems.map(\.name) == ["operationName", "query", "variables", "extensions"])
    }

    private struct CurrentUserQuery: GraphQLQuery {
        struct Data: Decodable, Sendable {}

        static let operationName: String? = "CurrentUser"
        static let document = "query CurrentUser { viewer { id } }"
        static let minifiedDocument = "query CurrentUser{viewer{id}}"

        let variables: Never? = nil
        let extensions: [String: StarwarsExample.AnyEncodable]? = nil
    }
}
