struct CodegenOutputPlan {
    let supportWriter: SupportWriter
    let documentsWriter: DocumentsWriter
    let schemaWriter: SchemaWriter

    let configuration: Configuration
    let topLevelDeclarations: [GeneratedTypeDeclaration]

    init(
        configuration: Configuration,
        resolvedDocuments: ResolvedDocuments,
        schema: Schema
    ) throws {
        let supportWriter = SupportWriter(
            configuration: configuration,
            hasMutation: resolvedDocuments.hasMutation,
            hasSubscription: resolvedDocuments.hasSubscription,
            requiresIndirectNullable: resolvedDocuments.requiresIndirectNullable,
            requiresResponseDecodingContext: resolvedDocuments.requiresResponseDecodingContext
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
        let topLevelDeclarations = supportWriter.topLevelDeclarations +
            documentsWriter.topLevelDeclarations + schemaWriter.topLevelDeclarations
        self.supportWriter = supportWriter
        self.configuration = configuration
        self.documentsWriter = documentsWriter
        self.schemaWriter = schemaWriter
        self.topLevelDeclarations = topLevelDeclarations
    }

    func validate() throws {
        try GeneratedTypeNameValidator(outputPlan: self).validate()
    }

    func write(using fileOutput: FileOutput) throws {
        try documentsWriter.write(using: fileOutput)
        try schemaWriter.write(using: fileOutput)
        try supportWriter.write(using: fileOutput)
    }
}
