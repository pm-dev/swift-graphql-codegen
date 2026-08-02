import Foundation

struct SchemaWriter {
    let configuration: Configuration
    let schema: Schema
    let resolvedDocuments: ResolvedDocuments

    private var schemaDirectory: URL {
        configuration.output.schema.directory
    }

    func write(using fileOutput: FileOutput) async throws {
        try await writeCustomScalars(using: fileOutput)
        try await writeEnums(using: fileOutput)
        try await writeInputObjects(using: fileOutput)
    }

    private func writeCustomScalars(using fileOutput: FileOutput) async throws {
        var scalarsDir = schemaDirectory
        if let scalarDirectoryName = configuration.output.schema.scalars.directoryName {
            scalarsDir.append(path: scalarDirectoryName, directoryHint: .isDirectory)
        }
        await fileOutput.remove(at: scalarsDir)
        await fileOutput.createDirectory(at: scalarsDir)
        for scalar in schema.typeCache.scalars.values {
            guard !scalar.ast.isNativeSwiftType else { continue }
            guard resolvedDocuments.usedTypes.contains(scalar.ast.name) else { continue }
            let filename = "\(scalar.ast.name).graphqls.swift"
            let url = scalarsDir.appending(path: filename, directoryHint: .notDirectory)
            guard !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
                // Will not overwrite existing scalar file
                await fileOutput.save(at: url)
                continue
            }
            var file = SwiftFileWriter()
            file.setHeader(configuration.output.schema.scalars.header)
            file.setImports(configuration.output.schema.scalars.importedModules)
            file.addType(SchemaScalarBuilder(scalar: scalar))
            try await file.write(to: url, configuration: configuration, using: fileOutput)
        }
    }

    private func writeEnums(using fileOutput: FileOutput) async throws {
        var enumsDir = schemaDirectory
        if let enumDirectoryName = configuration.output.schema.enums.directoryName {
            enumsDir.append(path: enumDirectoryName, directoryHint: .isDirectory)
        }
        await fileOutput.remove(at: enumsDir)
        await fileOutput.createDirectory(at: enumsDir)
        for `enum` in schema.typeCache.enums.values {
            guard !`enum`.ast.isSystemType else { continue }
            guard resolvedDocuments.usedTypes.contains(`enum`.ast.name) else { continue }
            var file = SwiftFileWriter()
            file.setHeader(configuration.output.schema.enums.header)
            file.setImports(configuration.output.schema.enums.importedModules)
            file.addType(SchemaEnumBuilder(enum: `enum`, configuration: configuration))
            try await file.write(
                to: enumsDir.appending(path: "\(`enum`.ast.name).graphqls.swift", directoryHint: .notDirectory),
                configuration: configuration,
                using: fileOutput
            )
        }
    }

    private func writeInputObjects(using fileOutput: FileOutput) async throws {
        var inputObjectsDir = schemaDirectory
        if let inputObjectDirectoryName = configuration.output.schema.inputObjects.directoryName {
            inputObjectsDir.append(path: inputObjectDirectoryName, directoryHint: .isDirectory)
        }
        await fileOutput.remove(at: inputObjectsDir)
        await fileOutput.createDirectory(at: inputObjectsDir)
        for inputObject in schema.typeCache.inputObjects.values {
            guard resolvedDocuments.usedTypes.contains(inputObject.ast.name) else { continue }
            var file = SwiftFileWriter()
            file.setHeader(configuration.output.schema.inputObjects.header)
            file.setImports(configuration.output.schema.inputObjects.importedModules)
            file.addType(SchemaInputObjectBuilder(inputObject: inputObject))
            try await file.write(
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
