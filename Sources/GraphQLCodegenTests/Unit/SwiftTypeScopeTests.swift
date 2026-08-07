@testable import GraphQLCodegen
import Testing

struct SwiftTypeScopeTests {
    @Test
    func leavesReferencesUnqualifiedWithoutCollision() {
        let scope = SwiftTypeScope(declarations: [SwiftTypeIdentifier]())

        #expect(scope.reference(.init(.swift, "String")) == "String")
        #expect(scope.reference(.init(.foundation, "URL")) == "URL")
        #expect(scope.conformance("Decodable") == "Decodable")
        #expect(scope.conformance("Swift.Decodable") == "Decodable")
    }

    @Test
    func qualifiesOnlyTheCollidingReference() {
        let scope = SwiftTypeScope(
            declarations: [
                SwiftTypeIdentifier(swiftName: "Decoder"),
                SwiftTypeIdentifier(swiftName: "URL"),
            ]
        )

        #expect(scope.reference(.init(.swift, "Decoder")) == "Swift.Decoder")
        #expect(scope.reference(.init(.foundation, "URL")) == "Foundation.URL")
        #expect(scope.reference(.init(.swift, "String")) == "String")
    }

    @Test
    func qualifiesStandardLibraryConformanceOnCollision() {
        let scope = SwiftTypeScope(
            declarations: [SwiftTypeIdentifier(swiftName: "Decodable")]
        )

        #expect(scope.conformance("Decodable") == "Swift.Decodable")
        #expect(scope.conformance("Swift.Decodable") == "Swift.Decodable")
        #expect(scope.conformance("CustomProtocol") == "CustomProtocol")
    }

    @Test
    func qualifiesOnlyReferenceTokensInSource() {
        let scope = SwiftTypeScope(
            declarations: [
                SwiftTypeIdentifier(swiftName: "Decoder"),
                SwiftTypeIdentifier(swiftName: "Sendable"),
            ]
        )
        let source = """
        /// Decoder remains unchanged in documentation.
        let decoder: Decoder
        let nested: Operation.Decoder
        let closure: @Sendable () -> Void
        let text = "Decoder"
        """

        let qualified = scope.qualify(
            source,
            references: [
                .init(.swift, "Decoder"),
                .init(.swift, "Sendable"),
            ]
        )

        #expect(qualified.contains("/// Decoder remains unchanged"))
        #expect(qualified.contains("let decoder: Swift.Decoder"))
        #expect(qualified.contains("let nested: Operation.Decoder"))
        #expect(qualified.contains("@Sendable"))
        #expect(qualified.contains("let text = \"Decoder\""))
    }
}
