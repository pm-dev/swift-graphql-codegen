import Foundation

public struct Codegen: Sendable {
    struct Error: Swift.Error, CustomStringConvertible {
        let description: String
    }

    private struct PreparedInput {
        let documents: Documents
        let schema: Schema
        let deprecationDiagnostics: [DeprecationUsageValidator.Diagnostic]
    }

    private let configuration: Configuration
    private let urlSession: URLSession

    public init(_ configuration: Configuration, urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
    }

    /// Writes a persisted-operation manifest without generating or modifying Swift output files.
    ///
    /// Operation bodies use the document formatting configured for generated operations.
    public func generatePersistedOperationManifestFile(at manifestURL: URL) async throws {
        let manifest = try PersistedOperationManifest(
            documents: await prepareInput().documents,
            minifyDocument: configuration.output.documents.operations.minifyDocument
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try FileManager.default.createDirectory(
            at: manifestURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: manifestURL, options: .atomic)
    }

    public func run() async throws {
        let start = Date()
        let preparedInput = try await prepareInput()
        let resolvedDocuments = try DocumentsResolver(
            schema: preparedInput.schema,
            documents: preparedInput.documents
        ).resolve()
        let outputPlan = try CodegenOutputPlan(
            configuration: configuration,
            resolvedDocuments: resolvedDocuments,
            schema: preparedInput.schema
        )
        try outputPlan.validate()
        for diagnostic in preparedInput.deprecationDiagnostics {
            print("Warning: \(diagnostic)")
        }

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

    private func prepareInput() async throws -> PreparedInput {
        try configuration.validate()

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

        let deprecationDiagnostics = try DeprecationUsageValidator(
            documents: documents,
            graphQLJS: graphQLJS,
            policy: configuration.input.deprecationPolicy,
            schemaJSON: loadedSchema.schemaJSON
        ).validate()

        try DocumentsValidator(
            schemaJSON: loadedSchema.schemaJSON,
            documents: documents,
            graphQLJS: graphQLJS
        ).validate()

        return PreparedInput(
            documents: documents,
            schema: loadedSchema.schema,
            deprecationDiagnostics: deprecationDiagnostics
        )
    }
}
