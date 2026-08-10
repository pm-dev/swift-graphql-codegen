import Foundation

struct SchemaWriter {
    enum TypePlan {
        case `enum`(Schema.Enum)
        case inputObject(Schema.InputObject)
        case scalar(Schema.Scalar)

        var name: String {
            switch self {
            case .enum(let `enum`): `enum`.ast.name
            case .inputObject(let inputObject): inputObject.ast.name
            case .scalar(let scalar): scalar.ast.name
            }
        }
    }

    let configuration: Configuration

    let generatedScalarNames: Set<String>
    let indirectOneOfInputObjectFields: [String: Set<String>]
    let typePlans: [TypePlan]

    init(configuration: Configuration, schema: Schema, resolvedDocuments: ResolvedDocuments) {
        self.configuration = configuration
        self.generatedScalarNames = Set(
            schema.typeCache.scalars.values.lazy
                .filter(\.ast.requiresGeneratedTypeDefinition)
                .map(\.ast.name)
        )
        self.indirectOneOfInputObjectFields = resolvedDocuments.indirectOneOfInputObjectFields
        self.typePlans = resolvedDocuments.usedTypes.sorted().compactMap { name -> TypePlan? in
            if let scalar = schema.typeCache.scalars[name] {
                return scalar.ast.requiresGeneratedTypeDefinition ? .scalar(scalar) : nil
            }
            if let `enum` = schema.typeCache.enums[name] {
                return `enum`.ast.isSystemType ? nil : .enum(`enum`)
            }
            return schema.typeCache.inputObjects[name].map(TypePlan.inputObject)
        }
    }

    func validate() throws {
        guard let mappings = configuration.output.schema.scalars.mappings else { return }
        let invalidScalarNames = Set(mappings.keys).subtracting(generatedScalarNames).sorted()
        if !invalidScalarNames.isEmpty {
            throw Codegen.Error(description: """
            Custom scalar mappings must reference ID or a custom scalar declared by the schema.
            Invalid scalar mappings: \(invalidScalarNames.joined(separator: ", "))
            """)
        }
    }

    var topLevelDeclarations: [GeneratedTypeDeclaration] {
        typePlans.map { type in
            GeneratedTypeDeclaration(
                name: SwiftTypeIdentifier(swiftName: type.name),
                origin: .schema(.type(type.name))
            )
        }
    }

    private var schemaDirectory: URL {
        configuration.output.schema.directory
    }

    func write(using fileOutput: FileOutput) throws {
        if let destination = configuration.output.url(for: .schema) {
            try writeGeneratedFile(to: destination, using: fileOutput)
            return
        }
        try writeCustomScalars(using: fileOutput)
        try writeEnums(using: fileOutput)
        try writeInputObjects(using: fileOutput)
    }

    private func writeGeneratedFile(to destination: URL, using fileOutput: FileOutput) throws {
        let scalarConfiguration = configuration.output.schema.scalars
        var file = SwiftFileWriter()
        file.setHeader(scalarConfiguration.header)
        file.setImports(scalarConfiguration.importedModules)
        for type in typePlans {
            switch type {
            case .scalar(let scalar):
                file.addType(
                    SchemaScalarBuilder(
                        scalar: scalar,
                        swiftType: scalarConfiguration.swiftType(for: scalar.ast.name)
                    )
                )
            case .enum(let `enum`):
                file.addType(SchemaEnumBuilder(enum: `enum`))
            case .inputObject(let inputObject):
                file.addType(
                    SchemaInputObjectBuilder(
                        inputObject: inputObject,
                        indirectInputFields: indirectOneOfInputObjectFields[
                            inputObject.ast.name,
                            default: []
                        ]
                    )
                )
            }
        }
        try file.write(to: destination, configuration: configuration, using: fileOutput)
    }

    private func writeCustomScalars(using fileOutput: FileOutput) throws {
        let scalarConfiguration = configuration.output.schema.scalars
        var scalarsDir = schemaDirectory
        if let scalarDirectoryName = scalarConfiguration.directoryName {
            scalarsDir.append(path: scalarDirectoryName, directoryHint: .isDirectory)
        }
        fileOutput.remove(at: scalarsDir)
        fileOutput.createDirectory(at: scalarsDir)
        for type in typePlans {
            guard case .scalar(let scalar) = type else { continue }
            let filename = "\(scalar.ast.name).graphqls.swift"
            let url = scalarsDir.appending(path: filename, directoryHint: .notDirectory)
            if scalarConfiguration.preservesExistingFiles,
               FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                // Will not overwrite existing scalar file
                fileOutput.save(at: url)
                continue
            }
            var file = SwiftFileWriter()
            file.setHeader(scalarConfiguration.header)
            file.setImports(scalarConfiguration.importedModules)
            file.addType(
                SchemaScalarBuilder(
                    scalar: scalar,
                    swiftType: scalarConfiguration.swiftType(for: scalar.ast.name)
                )
            )
            try file.write(to: url, configuration: configuration, using: fileOutput)
        }
    }

    private func writeEnums(using fileOutput: FileOutput) throws {
        var enumsDir = schemaDirectory
        if let enumDirectoryName = configuration.output.schema.enums.directoryName {
            enumsDir.append(path: enumDirectoryName, directoryHint: .isDirectory)
        }
        fileOutput.remove(at: enumsDir)
        fileOutput.createDirectory(at: enumsDir)
        for type in typePlans {
            guard case .enum(let `enum`) = type else { continue }
            var file = SwiftFileWriter()
            file.setHeader(configuration.output.schema.enums.header)
            file.setImports(configuration.output.schema.enums.importedModules)
            file.addType(SchemaEnumBuilder(enum: `enum`))
            try file.write(
                to: enumsDir.appending(path: "\(`enum`.ast.name).graphqls.swift", directoryHint: .notDirectory),
                configuration: configuration,
                using: fileOutput
            )
        }
    }

    private func writeInputObjects(using fileOutput: FileOutput) throws {
        var inputObjectsDir = schemaDirectory
        if let inputObjectDirectoryName = configuration.output.schema.inputObjects.directoryName {
            inputObjectsDir.append(path: inputObjectDirectoryName, directoryHint: .isDirectory)
        }
        fileOutput.remove(at: inputObjectsDir)
        fileOutput.createDirectory(at: inputObjectsDir)
        for type in typePlans {
            guard case .inputObject(let inputObject) = type else { continue }
            var file = SwiftFileWriter()
            file.setHeader(configuration.output.schema.inputObjects.header)
            file.setImports(configuration.output.schema.inputObjects.importedModules)
            file.addType(
                SchemaInputObjectBuilder(
                    inputObject: inputObject,
                    indirectInputFields: indirectOneOfInputObjectFields[inputObject.ast.name, default: []]
                )
            )
            try file.write(
                to: inputObjectsDir.appending(
                    path: "\(inputObject.ast.name).graphqls.swift",
                    directoryHint: .notDirectory
                ),
                configuration: configuration,
                using: fileOutput
            )
        }
    }
}
