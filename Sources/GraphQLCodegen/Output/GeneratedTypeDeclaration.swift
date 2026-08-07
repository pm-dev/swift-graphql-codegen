import Foundation

struct GeneratedTypeDeclaration {
    enum Origin: CustomStringConvertible {
        case api(String)
        case fragment(name: String, file: URL)
        case operation(name: String?, file: URL)
        case schema(String)

        var description: String {
            switch self {
            case .api(let name):
                "Generated API type: \(name)"
            case .fragment(let name, let file):
                "Fragment: \(name)\nFile: \(file)"
            case .operation(let name, let file):
                "Operation: \(name ?? "<unnamed>")\nFile: \(file)"
            case .schema(let name):
                "Schema type: \(name)"
            }
        }

        var resolution: String {
            switch self {
            case .api:
                "Rename the conflicting generated GraphQL definition."
            case .fragment:
                "Rename the fragment so it produces a distinct Swift type name."
            case .operation:
                "Rename the operation so it produces a distinct Swift type name."
            case .schema:
                "Rename the schema type so it produces a distinct Swift type name."
            }
        }
    }

    let name: SwiftTypeIdentifier
    let origin: Origin
    let conformances: [String]
}
