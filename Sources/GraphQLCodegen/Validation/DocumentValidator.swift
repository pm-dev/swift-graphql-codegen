import Foundation

struct DocumentValidator {
    struct Error: Decodable {
        struct Location: Decodable {
            let line: Int
            let column: Int

            var description: String {
                "line: \(line), column: \(column)"
            }
        }

        let message: String
        let locations: [Location]

        var description: String {
            """
            \(message)
            \(locations.map(\.description).joined(separator: "\n"))
            """
        }
    }

    let documentText: String
    let graphQLJS: GraphQLJS
    let schemaJSON: String

    func validate() async throws -> [Error] {
        let errorsJSON = try await graphQLJS.validate(documentText, schemaJSON: schemaJSON)
        return try JSONDecoder().decode([Error].self, from: errorsJSON)
    }
}
