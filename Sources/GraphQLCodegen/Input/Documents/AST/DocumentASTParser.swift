@preconcurrency import JavaScriptCore

struct DocumentASTParser {
    let sourceText: String

    func parse() throws -> AST.Document {
        let astJSONString = GraphQLJS(sourceText: sourceText).parsed()
        return try JSONDecoder().decode(AST.Document.self, from: Data(astJSONString.utf8))
    }
}
