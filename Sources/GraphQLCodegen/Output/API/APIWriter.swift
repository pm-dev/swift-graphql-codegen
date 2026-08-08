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
            let httpGenerationPlan = HTTPGenerationPlan(
                configuration: configuration,
                hasSubscription: hasSubscription
            )
            let httpOutputs: [any APIOutput] = [
                DefaultEncodersWriter(plan: httpGenerationPlan, configuration: configuration),
                GraphQLOperationWriter(
                    configuration: configuration,
                    hasMutation: hasMutation,
                    hasSubscription: hasSubscription
                ),
                EncodersWriter(plan: httpGenerationPlan, configuration: configuration),
                URLSessionWriter(hasSubscription: hasSubscription, configuration: configuration),
                GraphQLRequestWriter(plan: httpGenerationPlan, configuration: configuration),
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
                origin: .api(typeName.unescaped)
            )
        }
    }

    private var httpSupportDirectory: URL {
        configuration.output.api.directory.appending(
            path: "HTTPSupport",
            directoryHint: .isDirectory
        )
    }

    func write(using fileOutput: FileOutput) throws {
        let destinationPath = configuration.output.api.directory
        fileOutput.createDirectory(at: destinationPath)
        if configuration.output.api.HTTPSupport != nil {
            fileOutput.createDirectory(at: httpSupportDirectory)
        } else {
            fileOutput.remove(at: httpSupportDirectory)
        }
        for output in outputs {
            try output.write(using: fileOutput)
        }
    }
}
