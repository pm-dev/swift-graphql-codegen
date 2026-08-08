@testable import GraphQLCodegen
import Testing

struct SchemaCoordinateTests {
    @Test
    func formatsSchemaCoordinates() {
        #expect(SchemaCoordinate.type("SearchInput").description == "SearchInput")
        #expect(
            SchemaCoordinate.member(type: "SearchInput", member: "term").description == "SearchInput.term"
        )
        #expect(
            SchemaCoordinate.argument(type: "Query", field: "search", argument: "criteria").description ==
                "Query.search(criteria:)"
        )
        #expect(SchemaCoordinate.directive("deprecated").description == "@deprecated")
        #expect(
            SchemaCoordinate.directiveArgument(directive: "deprecated", argument: "reason").description ==
                "@deprecated(reason:)"
        )
    }
}
