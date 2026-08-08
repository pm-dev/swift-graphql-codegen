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
                https://spec.graphql.org/September2025/#sel-DAFRCSBDTAoC6of
                URL: \(document.url)
                """)
            }
            let fileName = document.url.deletingPathExtension().lastPathComponent
            let fileNameParts = fileName.split {
                !$0.isLetter && !$0.isNumber && $0 != "_"
            }
            guard let firstFileNamePart = fileNameParts.first else {
                throw Codegen.Error(description: """
                Unable to derive a Swift type name for the unnamed operation because its filename contains no Swift identifier characters.
                URL: \(document.url)

                Name the GraphQL operation or rename the file.
                """)
            }
            var typeName = String(firstFileNamePart)
            for fileNamePart in fileNameParts.dropFirst() {
                typeName += String(fileNamePart).capitalizedFirst
            }
            if typeName.first?.isNumber == true {
                typeName = "_" + typeName
            }
            unescaped = typeName.hasSuffix(operationType) ? typeName : typeName + operationType
        }
    }

    var source: String {
        identifier(unescaped)
    }
}
