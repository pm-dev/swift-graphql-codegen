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
        let graphQLJS = try GraphQLJS()
        let loadedSchema = try await SchemaLoader(
            configuration: configuration,
            graphQLJS: graphQLJS,
            urlSession: urlSession
        ).load()
        let documents = try await DocumentsLoader(
            configuration: configuration,
            graphQLJS: graphQLJS
        ).load()

        // Validation
        if configuration.validation {
            try await DocumentsValidator(
                schema: loadedSchema.schema,
                schemaJSON: loadedSchema.validationJSON,
                documents: documents,
                graphQLJS: graphQLJS
            ).validate()
        }

        // Resolution
        let resolvedDocuments = try DocumentsResolver(
            schema: loadedSchema.schema,
            documents: documents
        ).resolve()

        // Output
        let fileOutput = FileOutput()
        do {
            try await DocumentsWriter(
                configuration: configuration,
                resolvedDocuments: resolvedDocuments
            ).write(using: fileOutput)
            try await SchemaWriter(
                configuration: configuration,
                schema: loadedSchema.schema,
                resolvedDocuments: resolvedDocuments
            ).write(using: fileOutput)
            try await APIWriter(
                configuration: configuration,
                hasMutation: resolvedDocuments.hasMutation,
                hasSubscription: resolvedDocuments.hasSubscription
            ).write(using: fileOutput)
            switch configuration.output.documents.operations.persistedOperations {
            case .registered(let manifestURL):
                try await PersistedOperationManifestWriter(
                    manifestURL: manifestURL,
                    documents: documents
                ).write(using: fileOutput)
            case .automatic, .none: break
            }
        } catch {
            let generationError = error
            do {
                try await fileOutput.discard()
            } catch {
                throw Codegen.Error(description: """
                Failed to generate output: \(generationError)
                Failed to discard staged output: \(error)
                """)
            }
            throw generationError
        }
        try await fileOutput.execute()
        print("Codegen completed in \((Date().timeIntervalSince(start) * 1000).rounded() / 1000) seconds")
    }
}
