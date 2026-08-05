import Foundation

struct GraphQLOperationWriter {
    let configuration: Configuration
    let hasMutation: Bool
    let hasSubscription: Bool

    private var accessLevel: String {
        configuration.output.api.accessLevel == .public ? "public " : ""
    }

    private var header: String {
        guard let header = configuration.output.api.header else { return "" }
        return "\(header)\n\n"
    }

    private var url: URL {
        configuration.output.api.directory.appending(
            path: "HTTPSupport/GraphQLOperation.swift",
            directoryHint: .notDirectory
        )
    }

    func write(using fileOutput: FileOutput) async throws {
        try await content().write(to: url, using: fileOutput)
    }

    private func content() -> String {
        """
        \(header)/// A `GraphQLOperation` represents a GraphQL document containing a single operation.
        \(accessLevel)protocol GraphQLOperation: Sendable {

            /// The optional name of the operation.
            /// https://spec.graphql.org/October2021/#sel-FAFRDCEAAAAFBBAAD-zM
            static var operationName: String? { get }
        \(operationSourceRequirements())

            /// The parameterized variables to execute the operation with.
            /// https://spec.graphql.org/October2021/#sec-Language.Variables
            var variables: Variables { get }

            /// Metadata associated with the operation to include in the request.
            var extensions: [String: AnyEncodable]? { get }

            associatedtype Variables: Encodable, Sendable
            associatedtype Data: Decodable, Sendable
        }

        \(accessLevel)protocol GraphQLQuery: GraphQLOperation {}\(mutationProtocol())\(subscriptionProtocol())
        """
    }

    private func operationSourceRequirements() -> String {
        switch configuration.output.documents.operations.persistedOperations {
        case .registered:
            """

                /// The SHA-256 hash of the registered executable operation document.
                static var hash: String { get }
            """
        case .automatic, .none:
            operationDocumentRequirements()
        }
    }

    private func operationDocumentRequirements() -> String {
        """

            /// The executable string operated on by a GraphQL service, containing
            /// an operation definition and zero or more fragment definitions.
            /// https://spec.graphql.org/October2021/#sec-Document
            static var document: String { get }

            /// A precomputed, lexically equivalent document with ignored characters removed.
            /// The generated HTTP encoders use this representation when `minifyDocument` is enabled.
            static var minifiedDocument: String { get }
        """
    }

    private func mutationProtocol() -> String {
        guard hasMutation else { return "" }
        return """


        \(accessLevel)protocol GraphQLMutation: GraphQLOperation {}
        """
    }

    private func subscriptionProtocol() -> String {
        guard hasSubscription else { return "" }
        return """


        \(accessLevel)protocol GraphQLSubscription: GraphQLOperation {}
        """
    }
}
