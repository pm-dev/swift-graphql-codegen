import Foundation
@testable import GraphQLCodegen
import Testing

struct GraphQL17BoundaryModelTests {
    @Test
    func decodesExecutableDescriptions() throws {
        let document = try DocumentASTParser(
            graphQLJS: GraphQLJS(),
            sourceText: #"""
            "Operation documentation."
            query Viewer(
              "Variable documentation."
              $includeDetails: Boolean!
            ) {
              viewer { name @include(if: $includeDetails) }
            }

            "Fragment documentation."
            fragment ViewerFields on Viewer { name }
            """#
        ).parse()

        guard case .operation(let operation) = document.definitions.first else {
            Issue.record("Expected an operation definition")
            return
        }
        guard case .fragment(let fragment) = document.definitions.last else {
            Issue.record("Expected a fragment definition")
            return
        }

        #expect(operation.description?.value == "Operation documentation.")
        #expect(operation.variableDefinitions?.first?.description?.value == "Variable documentation.")
        #expect(fragment.description?.value == "Fragment documentation.")
    }

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
    func executableDescriptionsDoNotChangeCanonicalText() throws {
        let graphQLJS = try GraphQLJS()
        let described = #"""
        "Operation documentation."
        query Viewer(
          "Variable documentation."
          $id: ID!
        ) {
          viewer(id: $id) { name }
        }

        "Fragment documentation."
        fragment ViewerFields on Viewer { name }
        """#
        let undescribed = """
        query Viewer($id: ID!) { viewer(id: $id) { name } }
        fragment ViewerFields on Viewer { name }
        """

        #expect(try graphQLJS.canonicalize(described) == graphQLJS.canonicalize(undescribed))
    }

    @Test
    func decodesDirectiveDefinitionLocation() throws {
        let data = Data(#""DIRECTIVE_DEFINITION""#.utf8)

        let location = try JSONDecoder().decode(__Schema.__DirectiveLocation.self, from: data)

        #expect(location == .DIRECTIVE_DEFINITION)
    }
}
