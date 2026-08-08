import Foundation

struct GraphQLOperationWriter: APIOutput {
    let configuration: Configuration
    let hasMutation: Bool
    let hasSubscription: Bool
    let relativePath = "HTTPSupport/GraphQLOperation.swift"

    var topLevelTypeNames: [SwiftTypeIdentifier] {
        var typeNames = [
            SwiftTypeIdentifier(swiftName: "GraphQLOperation"),
            SwiftTypeIdentifier(swiftName: "GraphQLSingleResponseOperation"),
            SwiftTypeIdentifier(swiftName: "GraphQLQuery"),
        ]
        if hasMutation {
            typeNames.append(SwiftTypeIdentifier(swiftName: "GraphQLMutation"))
        }
        if hasSubscription {
            typeNames.append(SwiftTypeIdentifier(swiftName: "GraphQLSubscription"))
        }
        return typeNames
    }

    private var accessLevel: String {
        configuration.output.api.accessLevel == .public ? "public " : ""
    }

    private var header: String {
        guard let header = configuration.output.api.header else { return "" }
        return "\(header)\n\n"
    }

    var source: String {
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

            /// The operation's variables erased for request encoding.
            /// Variable-free operations return `nil` so request encoders omit them.
            var requestVariables: AnyEncodable? { get }

            /// Metadata associated with the operation to include in the request.
            var extensions: [String: AnyEncodable]? { get }

            associatedtype Variables: Encodable, Sendable
            associatedtype Data: Decodable, Sendable
        }

        extension GraphQLOperation {
            \(accessLevel)var requestVariables: AnyEncodable? {
                let requestVariables: AnyEncodable = AnyEncodable(variables)
                return requestVariables
            }
        }

        extension GraphQLOperation where Variables == Never? {
            \(accessLevel)var requestVariables: AnyEncodable? { nil }
        }

        /// A `GraphQLSingleResponseOperation` produces one response and can be executed with `URLSession.request`.
        /// Queries and mutations have this capability; subscriptions produce a stream instead.
        \(accessLevel)protocol GraphQLSingleResponseOperation: GraphQLOperation {}

        \(accessLevel)protocol GraphQLQuery: GraphQLSingleResponseOperation {}\(mutationProtocol())\(subscriptionProtocol())
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


        \(accessLevel)protocol GraphQLMutation: GraphQLSingleResponseOperation {}
        """
    }

    private func subscriptionProtocol() -> String {
        guard hasSubscription else { return "" }
        return """


        \(accessLevel)protocol GraphQLSubscription: GraphQLOperation {}
        """
    }
}
