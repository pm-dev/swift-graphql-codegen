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

    func write() async throws {
        let destinationPath = configuration.output.api.directory
        await FileOutput.default.createDirectory(at: destinationPath)
        try await AnyEncodableWriter(configuration: configuration).write()
        try await GraphQLEnumWriter(configuration: configuration).write()
        try await GraphQLErrorWriter(configuration: configuration).write()
        try await GraphQLHasDefaultWriter(configuration: configuration).write()
        try await GraphQLNullableWriter(configuration: configuration).write()
        try await GraphQLResponseWriter(configuration: configuration).write()
        try await JSONValueWriter(configuration: configuration).write()

        // HTTP Support
        if configuration.output.api.HTTPSupport != nil {
            await FileOutput.default.createDirectory(at: HTTPSupportDirectory)
            try await DefaultEncodersWriter(
                hasSubscription: hasSubscription,
                configuration: configuration
            ).write()
            try await GraphQLOperationWriter(
                configuration: configuration,
                hasMutation: hasMutation,
                hasSubscription: hasSubscription
            ).write()
            try await EncodersWriter(
                hasSubscription: hasSubscription,
                configuration: configuration
            ).write()
            try await URLSessionWriter(
                hasSubscription: hasSubscription,
                configuration: configuration
            ).write()
            try await GraphQLRequestWriter(
                hasSubscription: hasSubscription,
                configuration: configuration
            ).write()
        } else {
            await FileOutput.default.remove(at: HTTPSupportDirectory)
        }
    }
}
