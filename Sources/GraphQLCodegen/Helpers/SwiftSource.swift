struct SwiftSource {
    let value: String

    var blockComment: String {
        let singleLine = value
            .replacingOccurrences(of: "*/", with: "* /")
            .components(separatedBy: .newlines)
            .joined(separator: " ")
        return "/* \(singleLine) */"
    }

    var multilineStringLiteral: String {
        var delimiterCount = 1
        while true {
            let hashes = String(repeating: "#", count: delimiterCount)
            let closesLiteral = value.contains("\"\"\"" + hashes)
            let activatesEscape = value.contains("\\" + hashes)
            if !closesLiteral && !activatesEscape {
                return "\(hashes)\"\"\"\n\(value)\n\"\"\"\(hashes)"
            }
            delimiterCount += 1
        }
    }

    var singleLineStringLiteral: String {
        var result = "\""
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x09: result.append("\\t")
            case 0x0A: result.append("\\n")
            case 0x0D: result.append("\\r")
            case 0x22: result.append("\\\"")
            case 0x5C: result.append("\\\\")
            case 0x00..<0x20, 0x7F:
                result.append("\\u{\(String(scalar.value, radix: 16))}")
            default:
                result.unicodeScalars.append(scalar)
            }
        }
        result.append("\"")
        return result
    }
}
