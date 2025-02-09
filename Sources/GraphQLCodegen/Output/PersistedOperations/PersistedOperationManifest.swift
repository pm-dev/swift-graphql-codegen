struct PersistedOperationManifest: Encodable {
    struct Operation: Encodable {
        let id: String
        let body: String
        let name: String?
        let type: String
    }

    let format = "apollo-persisted-query-manifest"
    let version = 1
    let operations: [Operation]
}
