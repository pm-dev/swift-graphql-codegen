protocol SupportOutput: Sendable {
    /// Configuration that determines the support output directory.
    var configuration: Configuration { get }

    /// Generated file path relative to the support output directory.
    var relativePath: String { get }

    /// Generated Swift source.
    var source: String { get }

    /// Top-level Swift types this output writes.
    var topLevelTypeNames: [SwiftTypeIdentifier] { get }

    /// Writes this output to its configured destination.
    func write(using fileOutput: FileOutput) throws
}

extension SupportOutput {
    var accessLevel: String {
        configuration.output.support.accessLevel == .public ? "public " : ""
    }

    var header: String {
        configuration.output.support.header.map { "\($0)\n\n" } ?? ""
    }

    var headerBeforeImports: String {
        configuration.output.support.header.map { "\($0)\n" } ?? ""
    }

    func write(using fileOutput: FileOutput) throws {
        try source.write(
            to: configuration.output.support.directory.appending(
                path: relativePath,
                directoryHint: .notDirectory
            ),
            using: fileOutput
        )
    }
}
