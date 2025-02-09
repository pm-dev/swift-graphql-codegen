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

    func write() async throws {
        try await content().write(to: url)
    }

    private func content() -> String {
        switch configuration.output.documents.operations.persistedOperations {
        case .registered: RegisteredPersistedOperations()
        case .automatic, .none: NoRegisteredPersistedOperations()
        }
    }

    private func NoRegisteredPersistedOperations() -> String {
        """
        \(header)/// A `GraphQLOperation` represents a GraphQL document containing a single operation.
        \(accessLevel)protocol GraphQLOperation: Sendable {

            /// The optional name of the operation.
            /// https://spec.graphql.org/October2021/#sel-FAFRDCEAAAAFBBAAD-zM
            static var operationName: String? { get }

            /// The executable string operated on by a GraphQL service, containing
            /// an operation definition and zero or more fragment definitions.
            /// https://spec.graphql.org/October2021/#sec-Document
            static var document: String { get }

            /// The parameterized variables to execute the operation with.
            /// https://spec.graphql.org/October2021/#sec-Language.Variables
            var variables: Variables { get }

            /// Metadata associated with the operation to include in the request.
            var extensions: [String: AnyEncodable]? { get }

            associatedtype Variables: Encodable, Sendable
            associatedtype Data: Decodable, Sendable
        }

        \(accessLevel)protocol GraphQLQuery: GraphQLOperation {}
        \(hasMutation ? "\(accessLevel)protocol GraphQLMutation: GraphQLOperation {}" : "")
        \(hasSubscription ? "\(accessLevel)protocol GraphQLSubscription: GraphQLOperation {}" : "")

        """
    }

    private func RegisteredPersistedOperations() -> String {
        """
        \(header)/// A `GraphQLOperation` represents a GraphQL document containing a single operation.
        \(accessLevel)protocol GraphQLOperation: Sendable {

            /// The optional name of the operation.
            /// https://spec.graphql.org/October2021/#sel-FAFRDCEAAAAFBBAAD-zM
            static var operationName: String? { get }

            /// A SHA-256 hash of the executable operation document. Registered persisted
            /// operations was specified as a configuration option during codegen, indicating
            /// the server does not support unknown operations and only registered document hashes
            /// are accepted by the server.
            static var hash: String { get }

            /// The parameterized variables to execute the operation with.
            /// https://spec.graphql.org/October2021/#sec-Language.Variables
            var variables: Variables { get }

            /// Metadata associated with the operation to include in the request.
            var extensions: [String: AnyEncodable]? { get }

            associatedtype Variables: Encodable, Sendable
            associatedtype Data: Decodable, Sendable
        }

        \(accessLevel)protocol GraphQLQuery: GraphQLOperation {}
        \(hasMutation ? "\(accessLevel)protocol GraphQLMutation: GraphQLOperation {}" : "")
        \(hasSubscription ? "\(accessLevel)protocol GraphQLSubscription: GraphQLOperation {}" : "")

        """
    }
}
