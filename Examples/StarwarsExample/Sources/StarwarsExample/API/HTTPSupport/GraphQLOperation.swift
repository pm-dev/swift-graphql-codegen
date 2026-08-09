// @generated

/// A `GraphQLOperation` represents a GraphQL document containing a single operation.
protocol GraphQLOperation: Sendable {

    /// The optional name of the operation.
    /// https://spec.graphql.org/September2025/#sel-FAFTDCFABAADFCBAAD-zM
    static var operationName: String? { get }

    /// A precomputed executable document with descriptions and ignored characters removed.
    /// https://spec.graphql.org/September2025/#sec-Document
    static var document: String { get }

    /// The parameterized variables to execute the operation with.
    /// https://spec.graphql.org/September2025/#sec-Language.Variables
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