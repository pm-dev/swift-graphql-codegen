import CryptoKit
import Foundation

struct Documents {
    let previouslyGenerated: [URL]
    let documents: [Document]
    let fragmentLookup: [String: Document.Fragment]

    func fragment(_ name: String) throws -> Document.Fragment {
        guard let fragment = fragmentLookup[name] else {
            throw Codegen.Error(description: """
            Unable to find fragment definition for \(name)

            Note: Turning on validation can help find other similar errors
            """)
        }
        return fragment
    }
}

struct Document: Sendable {
    enum Definition: Sendable {
        case operation(Operation)
        case fragment(String)
    }

    struct Operation: Sendable {
        let ast: AST.OperationDefinition
        let canonicalText: String
        let sourceText: Substring

        var hash: String {
            let digits = Array("0123456789abcdef".utf8)
            let capacity = 2 * SHA256.Digest.byteCount
            return String(unsafeUninitializedCapacity: capacity) { buffer -> Int in
                var index = 0
                for byte in SHA256.hash(data: Data(canonicalText.utf8)) {
                    buffer[index] = digits[Int(byte >> 4)]
                    buffer[index + 1] = digits[Int(byte & 0x0F)]
                    index += 2
                }
                return capacity
            }
        }
    }

    struct Fragment {
        let file: URL
        let ast: AST.FragmentDefinition
        let sourceText: Substring
    }

    let url: URL
    let definitions: [Definition]
    let relativePath: String

    func outputURL(_ configuration: Configuration) -> URL {
        switch configuration.output.documents.directory {
        case .definition:
            url.appendingPathExtension("swift")
        case .directory(let outputDirectory):
            outputDirectory.appending(
                path: relativePath + ".swift",
                directoryHint: .notDirectory
            )
        }
    }
}
