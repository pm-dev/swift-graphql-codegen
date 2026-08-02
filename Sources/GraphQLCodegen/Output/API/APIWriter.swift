import Foundation

struct APIWriter {
    let configuration: Configuration
    let hasMutation: Bool
    let hasSubscription: Bool

    private var HTTPSupportDirectory: URL {
        configuration.output.api.directory.appending(
            path: "HTTPSupport",
            directoryHint: .isDirectory
        )
    }

    func write(using fileOutput: FileOutput) async throws {
        let destinationPath = configuration.output.api.directory
        await fileOutput.createDirectory(at: destinationPath)
        try await AnyEncodableWriter(configuration: configuration).write(using: fileOutput)
        try await GraphQLEnumWriter(configuration: configuration).write(using: fileOutput)
        try await GraphQLErrorWriter(configuration: configuration).write(using: fileOutput)
        try await GraphQLHasDefaultWriter(configuration: configuration).write(using: fileOutput)
        try await GraphQLNullableWriter(configuration: configuration).write(using: fileOutput)
        try await GraphQLResponseWriter(configuration: configuration).write(using: fileOutput)
        try await JSONValueWriter(configuration: configuration).write(using: fileOutput)

        // HTTP Support
        if configuration.output.api.HTTPSupport != nil {
            await fileOutput.createDirectory(at: HTTPSupportDirectory)
            try await DefaultEncodersWriter(
                hasSubscription: hasSubscription,
                configuration: configuration
            ).write(using: fileOutput)
            try await GraphQLOperationWriter(
                configuration: configuration,
                hasMutation: hasMutation,
                hasSubscription: hasSubscription
            ).write(using: fileOutput)
            try await EncodersWriter(
                hasSubscription: hasSubscription,
                configuration: configuration
            ).write(using: fileOutput)
            try await URLSessionWriter(
                hasSubscription: hasSubscription,
                configuration: configuration
            ).write(using: fileOutput)
            try await GraphQLRequestWriter(
                hasSubscription: hasSubscription,
                configuration: configuration
            ).write(using: fileOutput)
        } else {
            await fileOutput.remove(at: HTTPSupportDirectory)
        }
    }
}
