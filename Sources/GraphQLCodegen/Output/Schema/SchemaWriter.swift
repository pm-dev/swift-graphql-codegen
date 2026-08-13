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

    var topLevelDeclarations: [GeneratedTypeDeclaration] {
        typePlans.map { type in
            GeneratedTypeDeclaration(
                name: SwiftTypeIdentifier(swiftName: type.name),
                origin: .schema(.type(type.name))
            )
        }
    }

    init(configuration: Configuration, schema: Schema, resolvedDocuments: ResolvedDocuments) {
        self.configuration = configuration
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

    func write(using fileOutput: FileOutput) throws {
        let schemaConfiguration = configuration.output.schema
        let schemaDirectory = schemaConfiguration.directory
        fileOutput.createDirectory(at: schemaDirectory)

        var importedModules = schemaConfiguration.importedModules
        for type in typePlans {
            guard case .scalar(let scalar) = type else { continue }
            if let module = schemaConfiguration.scalars.scalarMapping[scalar.ast.name]?.module {
                importedModules.append(module.name)
            }
        }

        var file = SwiftFileWriter()
        file.setHeader(schemaConfiguration.header)
        file.setImports(importedModules)
        for type in typePlans {
            switch type {
            case .enum(let `enum`):
                file.addType(SchemaEnumBuilder(enum: `enum`))
            case .inputObject(let inputObject):
                file.addType(SchemaInputObjectBuilder(inputObject: inputObject))
            case .scalar(let scalar):
                file.addType(SchemaScalarBuilder(scalar: scalar))
            }
        }
        try file.write(
            to: schemaDirectory.appending(path: "Schema.swift", directoryHint: .notDirectory),
            configuration: configuration,
            using: fileOutput
        )
    }
}
