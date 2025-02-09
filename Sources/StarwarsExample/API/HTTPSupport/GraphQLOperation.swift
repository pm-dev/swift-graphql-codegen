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

    /// The parameterized variables to execute the operation with.
    /// https://spec.graphql.org/October2021/#sec-Language.Variables
    var variables: Variables { get }

    /// Metadata associated with the operation to include in the request.
    var extensions: [String: AnyEncodable]? { get }

    associatedtype Variables: Encodable, Sendable
    associatedtype Data: Decodable, Sendable
}

protocol GraphQLQuery: GraphQLOperation {}


