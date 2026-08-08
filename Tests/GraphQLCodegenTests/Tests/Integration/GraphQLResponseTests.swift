import Foundation
@testable import StarwarsExample
import Testing

struct GraphQLResponseTests {
    @Test
    func treatsExplicitNullDataAsAnExecutionResult() throws {
        let response = try JSONDecoder().decode(
            GraphQLResponse<Payload>.self,
            from: Data(
                #"""
                {
                  "data": null,
                  "errors": [{ "message": "The root result could not be resolved." }]
                }
                """#.utf8
            )
        )

        guard case .executionResult(let executionResult) = response else {
            Issue.record("Expected an execution result")
            return
        }
        #expect(executionResult.data == nil)
        #expect(executionResult.errors?.count == 1)
    }

    @Test
    func treatsAbsentDataAsARequestErrorResult() throws {
        let response = try JSONDecoder().decode(
            GraphQLResponse<Payload>.self,
            from: Data(
                #"""
                { "errors": [{ "message": "The request is invalid." }] }
                """#.utf8
            )
        )

        guard case .requestError(let requestError) = response else {
            Issue.record("Expected a request error result")
            return
        }
        #expect(requestError.errors.count == 1)
    }

    @Test
    func rejectsNegativeErrorPathListIndices() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                GraphQLError.self,
                from: Data(
                    #"""
                    { "message": "Invalid path", "path": ["items", -1] }
                    """#.utf8
                )
            )
        }
    }

    private struct Payload: Decodable, Sendable {}
}
