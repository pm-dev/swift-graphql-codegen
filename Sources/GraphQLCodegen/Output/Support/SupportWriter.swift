import Foundation

struct SupportWriter {
    let configuration: Configuration

    private let outputs: [any SupportOutput]

    var topLevelDeclarations: [GeneratedTypeDeclaration] {
        outputs.flatMap(\.topLevelTypeNames).map { typeName in
            GeneratedTypeDeclaration(
                name: typeName,
                origin: .support(typeName.unescaped)
            )
        }
    }

    init(
        configuration: Configuration,
        hasMutation: Bool,
        hasSubscription: Bool,
        requiresIndirectNullable: Bool,
        requiresResponseDecodingContext: Bool
    ) {
        var outputs: [any SupportOutput] = [
            AnyEncodableWriter(configuration: configuration),
            GraphQLEnumWriter(configuration: configuration),
            GraphQLErrorWriter(configuration: configuration),
            GraphQLHasDefaultWriter(configuration: configuration),
            GraphQLNullableWriter(
                configuration: configuration,
                requiresIndirectNullable: requiresIndirectNullable
            ),
            GraphQLResponseWriter(
                configuration: configuration,
                requiresResponseDecodingContext: requiresResponseDecodingContext
            ),
            JSONValueWriter(configuration: configuration),
        ]
        if configuration.output.support.HTTPSupport != nil {
            let httpGenerationPlan = HTTPGenerationPlan(
                configuration: configuration,
                hasSubscription: hasSubscription
            )
            let httpOutputs: [any SupportOutput] = [
                DefaultEncodersWriter(plan: httpGenerationPlan, configuration: configuration),
                GraphQLOperationWriter(
                    configuration: configuration,
                    hasMutation: hasMutation,
                    hasSubscription: hasSubscription,
                    requiresResponseDecodingContext: requiresResponseDecodingContext
                ),
                EncodersWriter(plan: httpGenerationPlan, configuration: configuration),
                URLSessionWriter(hasSubscription: hasSubscription, configuration: configuration),
                GraphQLRequestWriter(
                    plan: httpGenerationPlan,
                    configuration: configuration,
                    requiresResponseDecodingContext: requiresResponseDecodingContext
                ),
            ]
            outputs.append(contentsOf: httpOutputs)
        }
        self.configuration = configuration
        self.outputs = outputs
    }

    func write(using fileOutput: FileOutput) throws {
        let destinationPath = configuration.output.support.directory
        fileOutput.createDirectory(at: destinationPath)

        var preamble: [String] = []
        if let header = configuration.output.support.header {
            preamble.append(header)
        }
        if let httpSupport = configuration.output.support.HTTPSupport {
            if httpSupport.persistedOperations != nil {
                preamble.append("import CryptoKit")
            }
            preamble.append("import Foundation")
        }

        var sections: [String] = []
        if !preamble.isEmpty {
            sections.append(preamble.joined(separator: "\n"))
        }
        sections.append(contentsOf: outputs.map(\.source))
        let source = sections.joined(separator: "\n\n") + "\n"
        try source.write(
            to: destinationPath.appending(path: "Support.swift", directoryHint: .notDirectory),
            using: fileOutput
        )
    }
}
