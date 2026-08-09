@testable import Fixtures
import Foundation
import Testing

struct GraphQLHasDefaultTests {
    @Test
    func testUseDefaultOmitsValues() throws {
        let data = try JSONEncoder().encode(DefaultsQuery().variables)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json == "{}")
    }

    @Test
    func testValueEncodesValues() throws {
        let variables = DefaultsQuery(
            input: .value(DefaultsInput()),
            required: .value(3),
            optional: .null,
            list: .value([.value(5), nil])
        ).variables
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let data = try encoder.encode(variables)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json == #"{"input":{},"list":[5,null],"optional":null,"required":3}"#)
    }
}
