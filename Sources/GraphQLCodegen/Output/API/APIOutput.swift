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
    var accessLevel: String {
        configuration.output.api.accessLevel == .public ? "public " : ""
    }

    var header: String {
        configuration.output.api.header.map { "\($0)\n\n" } ?? ""
    }

    var headerBeforeImports: String {
        configuration.output.api.header.map { "\($0)\n" } ?? ""
    }

    var sourceWithoutHeader: String {
        for possibleHeader in [header, headerBeforeImports]
            .filter({ !$0.isEmpty })
            .sorted(by: { $0.count > $1.count })
        where source.hasPrefix(possibleHeader) {
            return String(source.dropFirst(possibleHeader.count))
        }
        return source
    }

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
