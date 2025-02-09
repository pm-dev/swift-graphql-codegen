protocol SwiftTypeBuildable {
    func build(configuration: Configuration) -> [String]
}

struct SwiftTypeBuilder: SwiftTypeBuildable {
    private struct Initializer {
        var isPublic = false
        var isThrowing = false
        var arguments: [String] = []
        var body: [String] = []
    }

    private var initializer = Initializer()
    private var declaration: [String]?
    private var contents: [String] = []
    private var nestedTypes: [SwiftTypeBuildable] = []
    private var started: Bool {
        declaration != nil
    }

    mutating func start(
        description: String?,
        isPublic: Bool,
        type: String,
        name: String,
        conformances: [String]
    ) {
        precondition(!started)
        var lines: [String] = []
        if let description {
            lines.append(contentsOf: _comment(description))
        }
        var line = "\(isPublic ? "public " : "")\(type) \(name)"
        if !conformances.isEmpty {
            line.append(": " + conformances.joined(separator: ", "))
        }
        line.append(" {")
        lines.append(line)
        declaration = lines
        initializer.isPublic = isPublic
    }

    mutating func addNestedType(_ builder: SwiftTypeBuildable) {
        precondition(started)
        nestedTypes.append(builder)
    }

    mutating func addInitializerArguments(_ lines: [String]) {
        precondition(started)
        initializer.arguments.append(contentsOf: lines)
    }

    mutating func addInitializerBody(_ lines: [String], isThrowing: Bool) {
        precondition(started)
        initializer.body.append(contentsOf: lines)
        initializer.isThrowing = initializer.isThrowing || isThrowing
    }

    mutating func addComment(_ comment: String) {
        precondition(started)
        contents.append(contentsOf: _comment(comment))
    }

    mutating func addDeprecation(_ deprecationReason: String?) {
        precondition(started)
        contents.append(_deprecation(deprecationReason))
    }

    mutating func addLine(_ line: String) {
        precondition(started)
        contents.append(line)
    }

    mutating func addEmptyLine() {
        precondition(started)
        contents.append("")
    }

    func build(configuration: Configuration) -> [String] {
        precondition(started)
        let indentation = configuration.output.indentation.string
        var lines = declaration!
        lines.append(contentsOf: contents.map { $0.isWhiteSpace ? "" : indentation + $0 })
        lines.append(contentsOf: buildInitializer(indentation: indentation))
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

    private func buildInitializer(indentation: String) -> [String] {
        var lines: [String] = []
        if !initializer.body.isEmpty {
            lines.append("")
            if initializer.arguments.count > 1 {
                lines.append(indentation + (initializer.isPublic ? "public " : "") + "init(")
                for (idx, line) in initializer.arguments.enumerated() {
                    let isLast = idx == initializer.arguments.count - 1
                    lines.append(indentation + indentation + line + (isLast ? "" : ","))
                }
                lines.append(indentation + ") " + (initializer.isThrowing ? "throws " : "") + "{")
            } else {
                var line = indentation
                if initializer.isPublic {
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
        }
        return lines
    }

    private func _comment(_ comment: String) -> [String] {
        comment.components(separatedBy: .newlines).map { line in "/// " + line }
    }

    private func _deprecation(_ deprecationReason: String?) -> String {
        var line = "@available(*, deprecated"
        if let deprecationReason, !deprecationReason.isEmpty {
            line.append(", message: \"\(deprecationReason)\")")
        } else {
            line.append(")")
        }
        return line
    }
}

extension String {
    fileprivate var isWhiteSpace: Bool {
        rangeOfCharacter(from: .whitespaces.inverted) == nil
    }
}
