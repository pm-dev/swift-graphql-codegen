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
    let schemaJSONString: String

    func validate() throws -> [Error] {
        let errorsJSON = try GraphQLJS(sourceText: documentText).validated(
            schemaJSONString: schemaJSONString
        )
        return try JSONDecoder().decode([Error].self, from: errorsJSON)
    }
}
