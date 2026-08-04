import Foundation

struct DocumentASTParser {
    let graphQLJS: GraphQLJS
    let sourceText: String

    func parse() async throws -> AST.Document {
        let astJSON = try await graphQLJS.parse(sourceText)
        return try JSONDecoder().decode(AST.Document.self, from: astJSON)
    }
}
