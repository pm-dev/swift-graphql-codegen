import Foundation
@testable import GraphQLCodegen
import Testing

struct IntrospectionQueryTests {
    @Test(arguments: [true, false])
    func appliesDeprecationPolicyToEverySupportedCollection(includeDeprecated: Bool) {
        let query = IntrospectionQuery(includeDeprecated: includeDeprecated).query
        let argument = includeDeprecated ? "true" : "false"

        #expect(query.contains("fields(includeDeprecated: \(argument))"))
        #expect(query.contains("args(includeDeprecated: \(argument))"))
        #expect(query.contains("inputFields(includeDeprecated: \(argument))"))
        #expect(query.contains("enumValues(includeDeprecated: \(argument))"))
        #expect(query.components(separatedBy: "args(includeDeprecated: \(argument))").count == 3)
    }

    @Test
    func requestsAndDecodesSeptember2025IntrospectionFields() throws {
        let query = IntrospectionQuery(includeDeprecated: true).query
        let inputObjectData = Data(
            #"{"description":null,"name":"Choice","inputFields":[],"isOneOf":true}"#.utf8
        )
        let inputValueData = Data(
            #"{"name":"oldValue","description":null,"type":{"kind":"SCALAR","name":"String"},"defaultValue":null,"isDeprecated":true,"deprecationReason":"Use newValue."}"#.utf8
        )

        let inputObject = try JSONDecoder().decode(__Schema.__NamedType.InputObject.self, from: inputObjectData)
        let inputValue = try JSONDecoder().decode(__Schema.__InputValue.self, from: inputValueData)

        #expect(query.contains("isOneOf"))
        #expect(query.contains("isDeprecated deprecationReason"))
        #expect(inputObject.isOneOf)
        #expect(inputValue.isDeprecated)
        #expect(inputValue.deprecationReason == "Use newValue.")
    }
}
