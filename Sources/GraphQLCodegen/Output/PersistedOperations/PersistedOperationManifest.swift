public struct PersistedOperationManifest: Codable {
    public struct Operation: Codable {
        public let id: String
        public let body: String
        public let name: String?
        public let type: String
    }

    public let format = "apollo-persisted-query-manifest"
    public let version = 1
    public var operations: [Operation]
}
