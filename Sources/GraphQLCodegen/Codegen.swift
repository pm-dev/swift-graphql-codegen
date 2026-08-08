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
        try configuration.validate()

        // Input
        let start = Date()
        let graphQLJS = try GraphQLJS()
        let loadedSchema = try await SchemaLoader(
            configuration: configuration,
            graphQLJS: graphQLJS,
            urlSession: urlSession
        ).load()
        let documents = try DocumentsLoader(
            configuration: configuration,
            graphQLJS: graphQLJS
        ).load()

        // Validation
        if case .enabled(let schemaJSON) = loadedSchema.validation {
            try DocumentsValidator(
                schemaJSON: schemaJSON,
                documents: documents,
                graphQLJS: graphQLJS
            ).validate()
        }

        // Resolution
        let resolvedDocuments = try DocumentsResolver(
            schema: loadedSchema.schema,
            documents: documents
        ).resolve()
        let outputPlan = try CodegenOutputPlan(
            configuration: configuration,
            documents: documents,
            resolvedDocuments: resolvedDocuments,
            schema: loadedSchema.schema
        )
        try outputPlan.validate()

        // Output
        let fileOutput = FileOutput()
        do {
            try outputPlan.write(using: fileOutput)
        } catch {
            let generationError = error
            do {
                try fileOutput.discard()
            } catch {
                throw Codegen.Error(description: """
                Failed to generate output: \(generationError)
                Failed to discard staged output: \(error)
                """)
            }
            throw generationError
        }
        try fileOutput.execute()
        print("Codegen completed in \((Date().timeIntervalSince(start) * 1000).rounded() / 1000) seconds")
    }
}
