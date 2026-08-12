import CryptoKit
import Foundation

public struct PersistedOperationManifest: Codable, Sendable {
    public struct Operation: Codable, Sendable {
        public let id: String
        public let body: String
        public let name: String?
        public let type: String
    }

    public let format: String
    public let version: Int
    public var operations: [Operation]

    init(documents: Documents, minifyDocument: Bool) {
        self.format = "apollo-persisted-query-manifest"
        self.version = 1
        self.operations = documents.documents
            .flatMap(\.definitions)
            .compactMap { definition -> Operation? in
                guard case .operation(let operation) = definition else { return nil }
                let documentText = minifyDocument
                    ? operation.canonicalText
                    : operation.documentText
                return Operation(
                    id: Self.hash(documentText),
                    body: documentText,
                    name: operation.ast.name?.value,
                    type: operation.ast.operation.rawValue
                )
            }
    }

    private static func hash(_ sourceText: String) -> String {
        let digits = Array("0123456789abcdef".utf8)
        let capacity = 2 * SHA256.Digest.byteCount
        return String(unsafeUninitializedCapacity: capacity) { buffer -> Int in
            var index = 0
            for byte in SHA256.hash(data: Data(sourceText.utf8)) {
                buffer[index] = digits[Int(byte >> 4)]
                buffer[index + 1] = digits[Int(byte & 0x0F)]
                index += 2
            }
            return capacity
        }
    }
}
