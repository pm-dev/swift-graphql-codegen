import Foundation

public struct Codegen: Sendable {
    struct Error: Swift.Error, CustomStringConvertible {
        let description: String
    }

    private let configuration: Configuration
    private let urlSession: URLSession

    public init(_ configuration: Configuration, urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
    }

    public func run() async throws {
        // Input
        let start = Date()
        let schema = try await SchemaLoader(configuration: configuration, urlSession: urlSession).load()
        let documents = try DocumentsLoader(configuration: configuration).load()

        // Validation
        if configuration.validation {
            try DocumentsValidator(
                schema: schema,
                documents: documents
            ).validate()
        }

        // Resolution
        let resolvedDocuments = try DocumentsResolver(
            schema: schema,
            documents: documents
        ).resolve()

        // Output
        let fileOutput = FileOutput()
        try await FileOutput.$current.withValue(fileOutput) {
            do {
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
                try await fileOutput.execute()
            } catch {
                await fileOutput.discard()
                throw error
            }
        }
        print("Codegen completed in \((Date().timeIntervalSince(start) * 1000).rounded() / 1000) seconds")
    }
}
