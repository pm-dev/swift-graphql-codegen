struct CodegenOutputPlan {
    let apiWriter: APIWriter
    let documentsWriter: DocumentsWriter
    let manifestWriter: PersistedOperationManifestWriter?
    let schemaWriter: SchemaWriter

    let configuration: Configuration
    let topLevelDeclarations: [GeneratedTypeDeclaration]

    init(
        configuration: Configuration,
        documents: Documents,
        resolvedDocuments: ResolvedDocuments,
        schema: Schema
    ) throws {
        let apiWriter = APIWriter(
            configuration: configuration,
            hasMutation: resolvedDocuments.hasMutation,
            hasSubscription: resolvedDocuments.hasSubscription,
            requiresIndirectNullable: resolvedDocuments.requiresIndirectNullable
        )
        let documentsWriter = try DocumentsWriter(
            configuration: configuration,
            resolvedDocuments: resolvedDocuments
        )
        let schemaWriter = SchemaWriter(
            configuration: configuration,
            schema: schema,
            resolvedDocuments: resolvedDocuments
        )
        let manifestWriter: PersistedOperationManifestWriter? =
            switch configuration.output.documents.operations.persistedOperations {
        case .registered(let manifestURL):
            PersistedOperationManifestWriter(manifestURL: manifestURL, documents: documents)
        case .automatic, .none:
            nil
        }
        let topLevelDeclarations = apiWriter.topLevelDeclarations +
            documentsWriter.topLevelDeclarations + schemaWriter.topLevelDeclarations
        self.apiWriter = apiWriter
        self.configuration = configuration
        self.documentsWriter = documentsWriter
        self.manifestWriter = manifestWriter
        self.schemaWriter = schemaWriter
        self.topLevelDeclarations = topLevelDeclarations
    }

    func validate() throws {
        try GeneratedTypeNameValidator(outputPlan: self).validate()
    }

    func write(using fileOutput: FileOutput) async throws {
        try await documentsWriter.write(using: fileOutput)
        try await schemaWriter.write(using: fileOutput)
        try await apiWriter.write(using: fileOutput)
        try await manifestWriter?.write(using: fileOutput)
    }
}
