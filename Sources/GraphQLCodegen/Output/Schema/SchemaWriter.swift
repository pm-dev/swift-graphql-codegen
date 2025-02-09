import Foundation

struct SchemaWriter {
    let configuration: Configuration
    let schema: Schema
    let resolvedDocuments: ResolvedDocuments

    private var schemaDirectory: URL {
        configuration.output.schema.directory
    }

    func write() async throws {
        try await writeCustomScalars()
        try await writeEnums()
        try await writeInputObjects()
    }

    private func writeCustomScalars() async throws {
        var scalarsDir = schemaDirectory
        if let scalarDirectoryName = configuration.output.schema.scalars.directoryName {
            scalarsDir.append(path: scalarDirectoryName, directoryHint: .isDirectory)
        }
        await FileOutput.default.remove(at: scalarsDir)
        await FileOutput.default.createDirectory(at: scalarsDir)
        for scalar in schema.typeCache.scalars.values {
            guard !scalar.ast.isNativeSwiftType else { continue }
            guard resolvedDocuments.usedTypes.contains(scalar.ast.name) else { continue }
            let filename = "\(scalar.ast.name).graphqls.swift"
            let url = scalarsDir.appending(path: filename, directoryHint: .notDirectory)
            guard !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
                // Will not overwrite existing scalar file
                await FileOutput.default.save(at: url)
                continue
            }
            var file = SwiftFileWriter()
            file.setHeader(configuration.output.schema.scalars.header)
            file.setImports(configuration.output.schema.scalars.importedModules)
            file.addType(SchemaScalarBuilder(scalar: scalar))
            try await file.write(to: url, configuration: configuration)
        }
    }

    private func writeEnums() async throws {
        var enumsDir = schemaDirectory
        if let enumDirectoryName = configuration.output.schema.enums.directoryName {
            enumsDir.append(path: enumDirectoryName, directoryHint: .isDirectory)
        }
        await FileOutput.default.remove(at: enumsDir)
        await FileOutput.default.createDirectory(at: enumsDir)
        for `enum` in schema.typeCache.enums.values {
            guard !`enum`.ast.isSystemType else { continue }
            guard resolvedDocuments.usedTypes.contains(`enum`.ast.name) else { continue }
            var file = SwiftFileWriter()
            file.setHeader(configuration.output.schema.enums.header)
            file.setImports(configuration.output.schema.enums.importedModules)
            file.addType(SchemaEnumBuilder(enum: `enum`))
            try await file.write(
                to: enumsDir.appending(path: "\(`enum`.ast.name).graphqls.swift", directoryHint: .notDirectory),
                configuration: configuration
            )
        }
    }

    private func writeInputObjects() async throws {
        var inputObjectsDir = schemaDirectory
        if let inputObjectDirectoryName = configuration.output.schema.inputObjects.directoryName {
            inputObjectsDir.append(path: inputObjectDirectoryName, directoryHint: .isDirectory)
        }
        await FileOutput.default.remove(at: inputObjectsDir)
        await FileOutput.default.createDirectory(at: inputObjectsDir)
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
                configuration: configuration
            )
        }
    }
}
