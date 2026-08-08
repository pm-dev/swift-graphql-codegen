struct SwiftStructBuilder: SwiftTypeBuildable {
    enum PropertyValue {
        case unassigned(type: String, initialized: Initialized?)
        case assigned(String, type: String?)
        case computed(String, type: String)

        enum Initialized {
            case direct(defaultValue: String?)
            case flattened([InitializerArgument], indentation: Configuration.Output.Indentation)

            struct InitializerArgument {
                static func named(
                    _ name: String,
                    type: String,
                    description: String?,
                    defaultValue: String?
                ) -> InitializerArgument {
                    InitializerArgument(
                        name: name,
                        type: type,
                        description: description,
                        defaultValue: defaultValue
                    )
                }

                let name: String
                let type: String
                let description: String?
                let defaultValue: String?
            }
        }
    }

    private var builder: SwiftTypeBuilder

    init(
        description: String?,
        isPublic: Bool,
        name: String,
        conformances: [String]
    ) {
        builder = SwiftTypeBuilder(
            description: description,
            isPublic: isPublic,
            type: "struct",
            name: identifier(name),
            conformances: conformances
        )
    }

    func build(configuration: Configuration) -> [String] {
        builder.build(configuration: configuration)
    }

    mutating func addProperty(
        description: String?,
        deprecation: Deprecation?,
        isPublic: Bool,
        isStatic: Bool,
        immutable: Bool,
        name: String,
        value: PropertyValue
    ) {
        builder.addEmptyLine()
        if let description, !description.isEmpty {
            builder.addComment(description)
        }
        if let deprecation {
            builder.addDeprecation(deprecation.reason)
        }
        let creator =
            switch value {
            case .computed: "var"
            case .assigned, .unassigned: immutable ? "let" : "var"
            }
        let safeName = identifier(name)
        var declarationLine = "\(isPublic ? "public " : "")\(isStatic ? "static " : "")\(creator) \(safeName)"
        switch value {
        case .computed(let value, type: let type):
            declarationLine.append(": \(type)")
            for line in declarationLine.addingDefaultValue(value, isComputed: true) {
                builder.addLine(line)
            }
        case .assigned(let value, let type):
            if let type {
                declarationLine.append(": \(type)")
            }
            for line in declarationLine.addingDefaultValue(value) {
                builder.addLine(line)
            }
        case .unassigned(let type, let initialized):
            declarationLine.append(": \(type)")
            builder.addLine(declarationLine)
            switch initialized {
            case .direct(let defaultValue):
                builder.addPropertyInitializerArguments("\(safeName): \(type)".addingDefaultValue(defaultValue))
                builder.addPropertyInitializerBody(["self.\(safeName) = \(safeName)"], isThrowing: false)
            case .flattened(let initializerArguments, let indentation):
                for argument in initializerArguments {
                    builder.addPropertyInitializerArguments(
                        "\(identifier(argument.name)): \(argument.type)".addingDefaultValue(argument.defaultValue),
                        name: argument.name,
                        description: argument.description
                    )
                }
                var assignmentLines = ["self.\(safeName) = \(type)("]
                for (idx, argument) in initializerArguments.enumerated() {
                    let safeArgumentName = identifier(argument.name)
                    var ln = "\(indentation.string)\(safeArgumentName): \(safeArgumentName)"
                    let isLast = idx == initializerArguments.count - 1
                    if !isLast {
                        ln.append(",")
                    }
                    assignmentLines.append(ln)
                }
                assignmentLines.append(")")
                builder.addPropertyInitializerBody(assignmentLines, isThrowing: false)
            case .none: break
            }
        }
    }

    mutating func addNestedType(_ type: SwiftTypeBuildable) {
        builder.addNestedType(type)
    }

    mutating func addInitializer(
        arguments: [String],
        body: [String],
        isThrowing: Bool
    ) {
        builder.addInitializer(
            arguments: arguments,
            body: body,
            isThrowing: isThrowing
        )
    }
}

extension String {
    fileprivate func addingDefaultValue(_ defaultValue: String?, isComputed: Bool = false) -> [String] {
        guard let defaultValue else { return [self] }
        var lines: [String] = []
        let allLines = defaultValue.components(separatedBy: .newlines)
        for (idx, ln) in allLines.enumerated() {
            let line: String =
                if idx == 0 {
                    "\(self) \(isComputed ? "{" : "=") \(ln)"
                } else {
                    ln
                }
            if isComputed, idx == allLines.count - 1 {
                if allLines.count <= 1 {
                    lines.append(line + " }")
                } else {
                    lines.append(line)
                    lines.append("}")
                }
            } else {
                lines.append(line)
            }
        }
        return lines
    }
}
