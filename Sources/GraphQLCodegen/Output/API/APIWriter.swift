import Foundation

struct APIWriter {
    let configuration: Configuration

    private let outputs: [any APIOutput]

    init(
        configuration: Configuration,
        hasMutation: Bool,
        hasSubscription: Bool,
        requiresIndirectNullable: Bool
    ) {
        var outputs: [any APIOutput] = [
            AnyEncodableWriter(configuration: configuration),
            GraphQLEnumWriter(configuration: configuration),
            GraphQLErrorWriter(configuration: configuration),
            GraphQLHasDefaultWriter(configuration: configuration),
            GraphQLNullableWriter(
                configuration: configuration,
                requiresIndirectNullable: requiresIndirectNullable
            ),
            GraphQLResponseWriter(configuration: configuration),
            JSONValueWriter(configuration: configuration),
        ]
        if configuration.output.api.HTTPSupport != nil {
            let httpOutputs: [any APIOutput] = [
                DefaultEncodersWriter(hasSubscription: hasSubscription, configuration: configuration),
                GraphQLOperationWriter(
                    configuration: configuration,
                    hasMutation: hasMutation,
                    hasSubscription: hasSubscription
                ),
                EncodersWriter(hasSubscription: hasSubscription, configuration: configuration),
                URLSessionWriter(hasSubscription: hasSubscription, configuration: configuration),
                GraphQLRequestWriter(hasSubscription: hasSubscription, configuration: configuration),
            ]
            outputs.append(contentsOf: httpOutputs)
        }
        self.configuration = configuration
        self.outputs = outputs
    }

    var topLevelDeclarations: [GeneratedTypeDeclaration] {
        outputs.flatMap(\.topLevelTypeNames).map { typeName in
            GeneratedTypeDeclaration(
                name: typeName,
                origin: .api(typeName.unescaped),
                conformances: []
            )
        }
    }

    var moduleQualifiers: Set<SwiftTypeIdentifier> {
        outputs.reduce(into: []) { result, output in
            result.formUnion(output.moduleQualifiers)
        }
    }

    private var httpSupportDirectory: URL {
        configuration.output.api.directory.appending(
            path: "HTTPSupport",
            directoryHint: .isDirectory
        )
    }

    func write(using fileOutput: FileOutput, typeScope: SwiftTypeScope) async throws {
        let destinationPath = configuration.output.api.directory
        await fileOutput.createDirectory(at: destinationPath)
        if configuration.output.api.HTTPSupport != nil {
            await fileOutput.createDirectory(at: httpSupportDirectory)
        } else {
            await fileOutput.remove(at: httpSupportDirectory)
        }
        for output in outputs {
            try await output.write(using: fileOutput, typeScope: typeScope)
        }
    }
}
