import Foundation

struct DocumentASTParser {
    let graphQLJS: GraphQLJS
    let sourceText: String

    func parse() throws -> AST.Document {
        let astJSON = try graphQLJS.parse(sourceText)
        return try JSONDecoder().decode(AST.Document.self, from: astJSON)
    }
}
