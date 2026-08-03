import Foundation

struct DocumentASTParser {
    let sourceText: String

    func parse() throws -> AST.Document {
        let astJSON = try GraphQLJS(sourceText: sourceText).parsed()
        return try JSONDecoder().decode(AST.Document.self, from: astJSON)
    }
}
