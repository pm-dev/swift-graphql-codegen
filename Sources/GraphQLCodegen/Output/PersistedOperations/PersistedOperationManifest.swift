public struct PersistedOperationManifest: Codable {
    public struct Operation: Codable {
        public let id: String
        public let body: String
        public let name: String?
        public let type: String
    }

    public let format: String
    public let version: Int
    public var operations: [Operation]

    init(operations: [Operation]) {
        self.format = "apollo-persisted-query-manifest"
        self.version = 1
        self.operations = operations
    }
}
