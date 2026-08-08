import Foundation
@testable import GraphQLCodegen
import Testing

struct GraphQL17BoundaryModelTests {
    @Test
    func decodesMissingEmptyDocumentCollections() throws {
        let data = Data(
            #"""
            {
              "loc": { "start": 0, "end": 16 },
              "definitions": [
                {
                  "kind": "OperationDefinition",
                  "loc": { "start": 0, "end": 16 },
                  "operation": "query",
                  "selectionSet": {
                    "loc": { "start": 6, "end": 16 },
                    "selections": [
                      {
                        "kind": "Field",
                        "loc": { "start": 8, "end": 14 },
                        "name": {
                          "loc": { "start": 8, "end": 14 },
                          "value": "viewer"
                        }
                      }
                    ]
                  }
                }
              ]
            }
            """#.utf8
        )

        let document = try JSONDecoder().decode(GraphQLAST.Document.self, from: data)
        guard case .operation(let operation) = try #require(document.definitions.first) else {
            Issue.record("Expected an operation definition")
            return
        }
        let selection = try #require(operation.selectionSet.selections.first)

        #expect(operation.variableDefinitions == nil)
        #expect(!selection.hasOptionalDirective)
    }

    @Test
    func decodesDirectiveDefinitionLocation() throws {
        let data = Data(#""DIRECTIVE_DEFINITION""#.utf8)

        let location = try JSONDecoder().decode(__Schema.__DirectiveLocation.self, from: data)

        #expect(location == .DIRECTIVE_DEFINITION)
    }
}
