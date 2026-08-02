enum SwiftStringLiteral {
    static func multiline(_ value: String) -> String {
        var delimiterCount = 1
        while value.contains("\"\"\"" + String(repeating: "#", count: delimiterCount)) ||
            value.contains("\\" + String(repeating: "#", count: delimiterCount) + "(") {
            delimiterCount += 1
        }
        let hashes = String(repeating: "#", count: delimiterCount)
        return "\(hashes)\"\"\"\n\(value)\n\"\"\"\(hashes)"
    }

    static func singleLine(_ value: String) -> String {
        var result = "\""
        for character in value {
            switch character {
            case "\\": result.append("\\\\")
            case "\"": result.append("\\\"")
            case "\n": result.append("\\n")
            case "\r": result.append("\\r")
            case "\t": result.append("\\t")
            default: result.append(character)
            }
        }
        result.append("\"")
        return result
    }

    static func blockComment(_ value: String) -> String {
        let singleLine = value
            .replacingOccurrences(of: "*/", with: "* /")
            .components(separatedBy: .newlines)
            .joined(separator: " ")
        return "/* \(singleLine) */"
    }
}
