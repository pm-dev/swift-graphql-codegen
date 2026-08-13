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

    private struct StoredProperty {
        let name: String
        let storageName: String
    }

    private var builder: SwiftTypeBuilder
    private var reservedPropertyNames: Set<String> = []
    private var storedProperties: [StoredProperty] = []
    private let usesCodingKeys: Bool

    init(
        description: String?,
        isPublic: Bool,
        name: String,
        conformances: [String]
    ) {
        self.builder = SwiftTypeBuilder(
            description: description,
            isPublic: isPublic,
            type: "struct",
            name: identifier(name),
            conformances: conformances
        )
        self.usesCodingKeys = conformances.contains { conformance in
            SwiftConformanceName(source: conformance).usesCodingKeys
        }
    }

    mutating func reservePropertyNames(_ names: [String]) {
        reservedPropertyNames.formUnion(names)
    }

    func build(configuration: Configuration) -> [String] {
        var builder = builder
        if storedProperties.contains(where: { $0.storageName != identifier($0.name) }), usesCodingKeys {
            let indentation = configuration.output.indentation.string
            builder.addEmptyLine()
            builder.addLine("private enum CodingKeys: String, CodingKey {")
            for property in storedProperties {
                let rawValue = property.storageName == property.name ? "" :
                    " = \(SwiftSource(value: property.name).singleLineStringLiteral)"
                builder.addLine("\(indentation)case \(property.storageName)\(rawValue)")
            }
            builder.addLine("}")
        }
        return builder.build(configuration: configuration)
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
        let creator =
            switch value {
            case .computed: "var"
            case .assigned, .unassigned: immutable ? "let" : "var"
            }
        let safeName = identifier(name)
        let usesBackingStorage =
            switch value {
            case .unassigned: deprecation != nil
            case .assigned, .computed: false
            }
        let backingName = usesBackingStorage ? backingStorageName(for: name) : safeName
        if isStatic == false {
            switch value {
            case .assigned, .unassigned:
                storedProperties.append(
                    StoredProperty(
                        name: name,
                        storageName: usesBackingStorage ? backingName : safeName
                    )
                )
            case .computed: break
            }
        }
        if usesBackingStorage == false {
            if let description, !description.isEmpty {
                builder.addComment(description)
            }
            if let deprecation {
                builder.addDeprecation(deprecation.reason)
            }
        }
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
            if usesBackingStorage {
                builder.addLine("private \(creator) \(backingName): \(type)")
                builder.addEmptyLine()
                if let description, !description.isEmpty {
                    builder.addComment(description)
                }
                if let deprecation {
                    builder.addDeprecation(deprecation.reason)
                }
                declarationLine = "\(isPublic ? "public " : "")var \(safeName): \(type)"
                let computedValue = immutable ? backingName : "get { \(backingName) }\nset { \(backingName) = newValue }"
                for line in declarationLine.addingDefaultValue(computedValue, isComputed: true) {
                    builder.addLine(line)
                }
            } else {
                declarationLine.append(": \(type)")
                builder.addLine(declarationLine)
            }
            switch initialized {
            case .direct(let defaultValue):
                builder.addPropertyInitializerArguments("\(safeName): \(type)".addingDefaultValue(defaultValue))
                let storedName = usesBackingStorage ? backingName : safeName
                builder.addPropertyInitializerBody(["self.\(storedName) = \(safeName)"], isThrowing: false)
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

    func storageName(forProperty name: String) -> String {
        storedProperties.first { $0.name == name }?.storageName ?? identifier(name)
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

    private func backingStorageName(for propertyName: String) -> String {
        var name = "__\(propertyName)"
        let storedPropertyNames = Set(storedProperties.map(\.storageName))
        while reservedPropertyNames.contains(name) || storedPropertyNames.contains(name) {
            name = "_\(name)"
        }
        return name
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
