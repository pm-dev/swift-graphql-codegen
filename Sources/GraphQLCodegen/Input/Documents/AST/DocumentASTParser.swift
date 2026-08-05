import Foundation

struct DocumentASTParser {
    let graphQLJS: GraphQLJS
    let sourceText: String

    func parse() throws -> GraphQLAST.Document {
        let astJSON = try graphQLJS.parse(sourceText)
        return try JSONDecoder().decode(GraphQLAST.Document.self, from: astJSON)
    }
}
