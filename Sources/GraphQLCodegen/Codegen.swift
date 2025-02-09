import Foundation

public struct Codegen: Sendable {
    struct Error: Swift.Error, CustomStringConvertible {
        let description: String
    }

    private let configuration: Configuration

    public init(_ configuration: Configuration) {
        self.configuration = configuration
    }

    public func run() async throws {
        // Input
        let start = Date()
        let schema = try await SchemaLoader(configuration: configuration).load()
        let documents = try DocumentsLoader(configuration: configuration).load()

        // Validation
        if configuration.validation {
            try await DocumentsValidator(
                schema: schema,
                documents: documents
            ).validate()
        }

        // Resolution
        let resolvedDocuments = try await DocumentsResolver(
            schema: schema,
            documents: documents
        ).resolve()

        // Output
        try await DocumentsWriter(
            configuration: configuration,
            resolvedDocuments: resolvedDocuments
        ).write()
        try await SchemaWriter(
            configuration: configuration,
            schema: schema,
            resolvedDocuments: resolvedDocuments
        ).write()
        try await APIWriter(
            configuration: configuration,
            hasMutation: resolvedDocuments.hasMutation,
            hasSubscription: resolvedDocuments.hasSubscription
        ).write()
        switch configuration.output.documents.operations.persistedOperations {
        case .registered(let manifestURL):
            try await PersistedOperationManifestWriter(
                manifestURL: manifestURL,
                documents: documents
            ).write()
        case .automatic, .none: break
        }
        try await FileOutput.default.execute()
        print("Codgen completed in \((Date().timeIntervalSince(start) * 1000).rounded() / 1000) seconds")
    }
}
