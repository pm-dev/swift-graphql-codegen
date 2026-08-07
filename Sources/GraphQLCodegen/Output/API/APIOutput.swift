protocol APIOutput: Sendable {
    /// Configuration that determines the API output directory.
    var configuration: Configuration { get }

    /// Generated file path relative to the API output directory.
    var relativePath: String { get }

    /// Generated Swift source.
    var source: String { get }

    /// Top-level Swift types this output writes.
    var topLevelTypeNames: [SwiftTypeIdentifier] { get }

    /// Writes this output to its configured destination.
    func write(using fileOutput: FileOutput) throws
}

extension APIOutput {
    func write(using fileOutput: FileOutput) throws {
        try source.write(
            to: configuration.output.api.directory.appending(
                path: relativePath,
                directoryHint: .notDirectory
            ),
            using: fileOutput
        )
    }
}
