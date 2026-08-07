protocol SwiftTypeBuildable {
    func build(configuration: Configuration) -> [String]
}

struct SwiftTypeBuilder: SwiftTypeBuildable {
    private struct Initializer {
        var isThrowing = false
        var arguments: [String] = []
        var body: [String] = []
    }
    private let declaration: [String]
    private let isPublic: Bool
    private var propertyInitializer = Initializer()
    private var initializers: [Initializer] = []
    private var contents: [String] = []
    private var nestedTypes: [SwiftTypeBuildable] = []

    init(
        description: String?,
        isPublic: Bool,
        type: String,
        name: String,
        conformances: [String]
    ) {
        var lines: [String] = []
        if let description {
            lines.append(contentsOf: description.documentationCommentLines)
        }
        var line = "\(isPublic ? "public " : "")\(type) \(name)"
        if !conformances.isEmpty {
            line.append(": " + conformances.joined(separator: ", "))
        }
        line.append(" {")
        lines.append(line)
        self.declaration = lines
        self.isPublic = isPublic
    }

    mutating func addNestedType(_ builder: SwiftTypeBuildable) {
        nestedTypes.append(builder)
    }

    mutating func addInitializer(
        arguments: [String],
        body: [String],
        isThrowing: Bool
    ) {
        initializers.append(
            Initializer(
                isThrowing: isThrowing,
                arguments: arguments,
                body: body
            )
        )
    }

    mutating func addPropertyInitializerArguments(_ lines: [String]) {
        propertyInitializer.arguments.append(contentsOf: lines)
    }

    mutating func addPropertyInitializerBody(_ lines: [String], isThrowing: Bool) {
        propertyInitializer.body.append(contentsOf: lines)
        propertyInitializer.isThrowing = propertyInitializer.isThrowing || isThrowing
    }

    mutating func addComment(_ comment: String) {
        contents.append(contentsOf: comment.documentationCommentLines)
    }

    mutating func addDeprecation(_ deprecationReason: String?) {
        contents.append(_deprecation(deprecationReason))
    }

    mutating func addLine(_ line: String) {
        contents.append(line)
    }

    mutating func addEmptyLine() {
        contents.append("")
    }

    func build(configuration: Configuration) -> [String] {
        let indentation = configuration.output.indentation.string
        var lines = declaration
        lines.append(contentsOf: contents.map { $0.isWhiteSpace ? "" : indentation + $0 })
        lines.append(contentsOf: buildInitializers(indentation: indentation))
        for nested in nestedTypes {
            lines.append("")
            lines.append(
                contentsOf: nested.build(configuration: configuration).map {
                    $0.isWhiteSpace ? "" : indentation + $0
                }
            )
        }
        lines.append("}")
        return lines
    }

    private func buildInitializers(indentation: String) -> [String] {
        var lines: [String] = []
        lines.append(contentsOf: buildInitializer(propertyInitializer, indentation: indentation))
        for initializer in initializers {
            lines.append(contentsOf: buildInitializer(initializer, indentation: indentation))
        }
        return lines
    }

    private func buildInitializer(_ initializer: Initializer, indentation: String) -> [String] {
        guard !initializer.body.isEmpty else { return [] }
        var lines: [String] = [""]
        if initializer.arguments.count > 1 {
            lines.append(indentation + (isPublic ? "public " : "") + "init(")
            for (idx, line) in initializer.arguments.enumerated() {
                let isLast = idx == initializer.arguments.count - 1
                lines.append(indentation + indentation + line + (isLast ? "" : ","))
            }
            lines.append(indentation + ") " + (initializer.isThrowing ? "throws " : "") + "{")
        } else {
            var line = indentation
            if isPublic {
                line.append("public ")
            }
            line.append("init(")
            if let argumentLine = initializer.arguments.first {
                line.append(argumentLine)
            }
            line.append(") ")
            if initializer.isThrowing {
                line.append("throws ")
            }
            line.append("{")
            lines.append(line)
        }
        lines.append(contentsOf: initializer.body.map { indentation + indentation + $0 })
        lines.append(indentation + "}")
        return lines
    }

    private func _deprecation(_ deprecationReason: String?) -> String {
        var line = "@available(*, deprecated"
        if let deprecationReason, !deprecationReason.isEmpty {
            line.append(", message: \(SwiftSource(value: deprecationReason).singleLineStringLiteral))")
        } else {
            line.append(")")
        }
        return line
    }
}

extension String {
    fileprivate var documentationCommentLines: [String] {
        components(separatedBy: .newlines).map { line in "/// " + line }
    }

    fileprivate var isWhiteSpace: Bool {
        rangeOfCharacter(from: .whitespaces.inverted) == nil
    }
}
