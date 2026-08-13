import Foundation
import Testing
@testable import GraphQLCodegen

struct IntrospectionQueryTests {
    @Test
    func includesDeprecatedMembersFromEverySupportedCollection() {
        let query = IntrospectionQuery().query

        #expect(query.contains("fields(includeDeprecated: true)"))
        #expect(query.contains("args(includeDeprecated: true)"))
        #expect(query.contains("inputFields(includeDeprecated: true)"))
        #expect(query.contains("enumValues(includeDeprecated: true)"))
        #expect(query.components(separatedBy: "args(includeDeprecated: true)").count == 3)
    }

    @Test
    func requestsAndDecodesSeptember2025IntrospectionFields() throws {
        let query = IntrospectionQuery().query
        let inputObjectData = Data(
            #"{"description":null,"name":"Choice","inputFields":[],"isOneOf":true}"#.utf8
        )
        let inputValueData = Data(
            #"{"name":"oldValue","description":null,"type":{"kind":"SCALAR","name":"String"},"defaultValue":null,"isDeprecated":true,"deprecationReason":"Use newValue."}"#
                .utf8
        )
        let fieldData = Data(
            #"{"name":"oldField","description":null,"args":[],"type":{"kind":"SCALAR","name":"String"},"isDeprecated":true,"deprecationReason":"Use newField."}"#
                .utf8
        )
        let enumValueData = Data(
            #"{"name":"OLD_VALUE","description":null,"isDeprecated":true,"deprecationReason":"Use NEW_VALUE."}"#.utf8
        )

        let inputObject = try JSONDecoder().decode(__Schema.__NamedType.InputObject.self, from: inputObjectData)
        let inputValue = try JSONDecoder().decode(__Schema.__InputValue.self, from: inputValueData)
        let field = try JSONDecoder().decode(__Schema.__Field.self, from: fieldData)
        let enumValue = try JSONDecoder().decode(__Schema.__EnumValue.self, from: enumValueData)

        #expect(query.contains("isOneOf"))
        #expect(query.contains("isDeprecated deprecationReason"))
        #expect(inputObject.isOneOf)
        #expect(inputValue.deprecation?.reason == "Use newValue.")
        #expect(field.deprecation?.reason == "Use newField.")
        #expect(enumValue.deprecation?.reason == "Use NEW_VALUE.")
    }

    @Test
    func rejectsDeprecatedInputValueWithoutReason() {
        let inputValueData = Data(
            #"{"name":"oldValue","description":null,"type":{"kind":"SCALAR","name":"String"},"defaultValue":null,"isDeprecated":true,"deprecationReason":null}"#
                .utf8
        )

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(__Schema.__InputValue.self, from: inputValueData)
        }
    }
}
