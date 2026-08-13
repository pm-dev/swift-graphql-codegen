/// https://spec.graphql.org/September2025/#sec-Schema-Coordinates
enum SchemaCoordinate: CustomStringConvertible {
    case argument(type: String, field: String, argument: String)
    case directive(String)
    case directiveArgument(directive: String, argument: String)
    case member(type: String, member: String)
    case type(String)

    var description: String {
        switch self {
        case .argument(let type, let field, let argument):
            "\(type).\(field)(\(argument):)"
        case .directive(let directive):
            "@\(directive)"
        case .directiveArgument(let directive, let argument):
            "@\(directive)(\(argument):)"
        case .member(let type, let member):
            "\(type).\(member)"
        case .type(let type):
            type
        }
    }
}
