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

    let typePlans: [TypePlan]

    init(configuration: Configuration, schema: Schema, resolvedDocuments: ResolvedDocuments) {
        self.configuration = configuration
        self.typePlans = resolvedDocuments.usedTypes.sorted().compactMap { name -> TypePlan? in
            if let scalar = schema.typeCache.scalars[name] {
                return scalar.ast.isNativeSwiftType ? nil : .scalar(scalar)
            }
            if let `enum` = schema.typeCache.enums[name] {
                return `enum`.ast.isSystemType ? nil : .enum(`enum`)
            }
            return schema.typeCache.inputObjects[name].map(TypePlan.inputObject)
        }
    }

    var topLevelDeclarations: [GeneratedTypeDeclaration] {
        typePlans.map { type in
            GeneratedTypeDeclaration(
                name: SwiftTypeIdentifier(swiftName: type.name),
                origin: .schema(type.name)
            )
        }
    }

    private var schemaDirectory: URL {
        configuration.output.schema.directory
    }

    func write(using fileOutput: FileOutput) throws {
        try writeCustomScalars(using: fileOutput)
        try writeEnums(using: fileOutput)
        try writeInputObjects(using: fileOutput)
    }

    private func writeCustomScalars(using fileOutput: FileOutput) throws {
        var scalarsDir = schemaDirectory
        if let scalarDirectoryName = configuration.output.schema.scalars.directoryName {
            scalarsDir.append(path: scalarDirectoryName, directoryHint: .isDirectory)
        }
        fileOutput.remove(at: scalarsDir)
        fileOutput.createDirectory(at: scalarsDir)
        for type in typePlans {
            guard case .scalar(let scalar) = type else { continue }
            let filename = "\(scalar.ast.name).graphqls.swift"
            let url = scalarsDir.appending(path: filename, directoryHint: .notDirectory)
            guard !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
                // Will not overwrite existing scalar file
                fileOutput.save(at: url)
                continue
            }
            var file = SwiftFileWriter()
            file.setHeader(configuration.output.schema.scalars.header)
            file.setImports(configuration.output.schema.scalars.importedModules)
            file.addType(SchemaScalarBuilder(scalar: scalar))
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
            file.addType(SchemaInputObjectBuilder(inputObject: inputObject))
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
