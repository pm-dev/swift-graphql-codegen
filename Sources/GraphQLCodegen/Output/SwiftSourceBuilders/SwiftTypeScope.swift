import Foundation

struct SwiftTypeReference: Hashable {
    enum Module: String {
        case cryptoKit = "CryptoKit"
        case foundation = "Foundation"
        case swift = "Swift"
    }

    let module: Module
    let name: SwiftTypeIdentifier

    init(_ module: Module, _ name: String) {
        self.module = module
        self.name = SwiftTypeIdentifier(swiftName: name)
    }

    init?(nativeScalarName: String) {
        guard ["Bool", "Double", "Int", "String"].contains(nativeScalarName) else {
            return nil
        }
        self.init(.swift, nativeScalarName)
    }
}

struct SwiftTypeScope {
    private let declarations: Set<SwiftTypeIdentifier>

    init<S: Sequence>(declarations: S) where S.Element == SwiftTypeIdentifier {
        self.declarations = Set(declarations)
    }

    func adding<S: Sequence>(declarations: S) -> SwiftTypeScope where S.Element == SwiftTypeIdentifier {
        SwiftTypeScope(declarations: self.declarations.union(declarations))
    }

    func conformance(_ source: String) -> String {
        guard let reference = SwiftConformanceName(source: source).standardLibraryReference else {
            return source
        }
        return self.reference(reference)
    }

    func reference(_ reference: SwiftTypeReference) -> String {
        guard declarations.contains(reference.name) else { return reference.name.source }
        return reference.module.rawValue + "." + reference.name.source
    }

    func qualify(_ source: String, references: Set<SwiftTypeReference>) -> String {
        let replacements = references.reduce(into: [String: String]()) { result, reference in
            let qualified = self.reference(reference)
            guard qualified != reference.name.source else { return }
            result[reference.name.unescaped] = qualified
        }
        guard !replacements.isEmpty else { return source }
        return source.replacingTypeReferences(replacements)
    }
}

extension String {
    fileprivate func replacingTypeReferences(_ replacements: [String: String]) -> String {
        enum State {
            case blockComment
            case lineComment
            case multilineString
            case source
            case string
        }

        let bytes = Array(utf8)
        var output: [UInt8] = []
        var state = State.source
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            switch state {
            case .source:
                if bytes.hasPrefix([0x2F, 0x2F], at: index) {
                    output.append(contentsOf: bytes[index ..< index + 2])
                    index += 2
                    state = .lineComment
                } else if bytes.hasPrefix([0x2F, 0x2A], at: index) {
                    output.append(contentsOf: bytes[index ..< index + 2])
                    index += 2
                    state = .blockComment
                } else if bytes.hasPrefix([0x22, 0x22, 0x22], at: index) {
                    output.append(contentsOf: bytes[index ..< index + 3])
                    index += 3
                    state = .multilineString
                } else if byte == 0x22 {
                    output.append(byte)
                    index += 1
                    state = .string
                } else if byte.isIdentifierHead {
                    let start = index
                    index += 1
                    while index < bytes.count, bytes[index].isIdentifierBody {
                        index += 1
                    }
                    guard let identifier = String(bytes: bytes[start ..< index], encoding: .utf8) else {
                        preconditionFailure("A substring of valid Swift source must be valid UTF-8")
                    }
                    let previous = output.last { !$0.isWhitespace }
                    if previous != 0x2E, previous != 0x40, let replacement = replacements[identifier] {
                        output.append(contentsOf: replacement.utf8)
                    } else {
                        output.append(contentsOf: bytes[start ..< index])
                    }
                } else {
                    output.append(byte)
                    index += 1
                }
            case .lineComment:
                output.append(byte)
                index += 1
                if byte == 0x0A {
                    state = .source
                }
            case .blockComment:
                output.append(byte)
                index += 1
                if byte == 0x2A, index < bytes.count, bytes[index] == 0x2F {
                    output.append(bytes[index])
                    index += 1
                    state = .source
                }
            case .string:
                output.append(byte)
                index += 1
                if byte == 0x5C, index < bytes.count {
                    output.append(bytes[index])
                    index += 1
                } else if byte == 0x22 {
                    state = .source
                }
            case .multilineString:
                if bytes.hasPrefix([0x22, 0x22, 0x22], at: index) {
                    output.append(contentsOf: bytes[index ..< index + 3])
                    index += 3
                    state = .source
                } else {
                    output.append(byte)
                    index += 1
                }
            }
        }
        guard let result = String(bytes: output, encoding: .utf8) else {
            preconditionFailure("Replacing ASCII identifiers cannot invalidate UTF-8 source")
        }
        return result
    }
}

extension Array where Element == UInt8 {
    fileprivate func hasPrefix(_ prefix: [UInt8], at index: Int) -> Bool {
        guard index + prefix.count <= count else { return false }
        return self[index ..< index + prefix.count].elementsEqual(prefix)
    }
}

extension UInt8 {
    fileprivate var isIdentifierBody: Bool {
        isIdentifierHead || (0x30 ... 0x39).contains(self)
    }

    fileprivate var isIdentifierHead: Bool {
        self == 0x5F || (0x41 ... 0x5A).contains(self) || (0x61 ... 0x7A).contains(self)
    }

    fileprivate var isWhitespace: Bool {
        self == 0x09 || self == 0x0A || self == 0x0D || self == 0x20
    }
}
