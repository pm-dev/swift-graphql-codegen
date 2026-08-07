struct SwiftTypeIdentifier: Hashable {
    static let codingKey = SwiftTypeIdentifier(swiftName: "CodingKey")
    static let codingKeys = SwiftTypeIdentifier(swiftName: "CodingKeys")
    static let data = SwiftTypeIdentifier(swiftName: "Data")
    static let variables = SwiftTypeIdentifier(swiftName: "Variables")

    let unescaped: String

    init(capitalizing graphQLName: String) {
        unescaped = graphQLName.capitalizedFirst
    }

    init(swiftName: String) {
        unescaped = swiftName
    }

    init(operation: Document.Operation, in document: Document) throws {
        let operationType = operation.ast.operation.rawValue.capitalizedFirst
        if let name = operation.ast.name {
            unescaped = name.value + operationType
        } else {
            let operationCount = document.definitions.count { definition in
                switch definition {
                case .fragment: false
                case .operation: true
                }
            }
            guard operationCount == 1 else {
                throw Codegen.Error(description: """
                Missing operation name. Operations may only be unnamed if they're the only operation in the document.
                https://spec.graphql.org/October2021/#sel-FAFPTABABoC6of
                URL: \(document.url)
                """)
            }
            let fileName = document.url.deletingPathExtension().lastPathComponent
            unescaped = fileName.hasSuffix(operationType) ? fileName : fileName + operationType
        }
    }

    var source: String {
        identifier(unescaped)
    }
}
