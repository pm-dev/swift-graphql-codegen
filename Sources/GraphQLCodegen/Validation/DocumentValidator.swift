@preconcurrency import JavaScriptCore

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
        let errorsJSONString = GraphQLJS.validateDocument(documentText, schemaJSONString: schemaJSONString)
        if errorsJSONString == "[]" {
            return []
        } else if errorsJSONString.hasPrefix("{") {
            return [try JSONDecoder().decode(Error.self, from: Data(errorsJSONString.utf8))]
        }
        return try JSONDecoder().decode([Error].self, from: Data(errorsJSONString.utf8))
    }
}
