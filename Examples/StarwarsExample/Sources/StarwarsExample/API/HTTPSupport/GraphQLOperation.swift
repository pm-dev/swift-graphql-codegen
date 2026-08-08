// @generated

/// A `GraphQLOperation` represents a GraphQL document containing a single operation.
protocol GraphQLOperation: Sendable {

    /// The optional name of the operation.
    /// https://spec.graphql.org/October2021/#sel-FAFRDCEAAAAFBBAAD-zM
    static var operationName: String? { get }

    /// The executable string operated on by a GraphQL service, containing
    /// an operation definition and zero or more fragment definitions.
    /// https://spec.graphql.org/October2021/#sec-Document
    static var document: String { get }

    /// A precomputed, execution-equivalent document with executable descriptions and ignored characters removed.
    /// The generated HTTP encoders use this representation for persisted-operation hashes and when
    /// `minifyDocument` is enabled.
    static var minifiedDocument: String { get }

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
    var requestVariables: AnyEncodable? {
        let requestVariables: AnyEncodable = AnyEncodable(variables)
        return requestVariables
    }
}

extension GraphQLOperation where Variables == Never? {
    var requestVariables: AnyEncodable? { nil }
}

/// A `GraphQLSingleResponseOperation` produces one response and can be executed with `URLSession.request`.
/// Queries and mutations have this capability; subscriptions produce a stream instead.
protocol GraphQLSingleResponseOperation: GraphQLOperation {}

protocol GraphQLQuery: GraphQLSingleResponseOperation {}

protocol GraphQLMutation: GraphQLSingleResponseOperation {}

protocol GraphQLSubscription: GraphQLOperation {}