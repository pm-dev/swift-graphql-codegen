protocol APIOutput: Sendable {
    /// Configuration that determines the API output directory.
    var configuration: Configuration { get }

    /// Generated file path relative to the API output directory.
    var relativePath: String { get }

    /// Unqualified generated Swift source.
    var source: String { get }

    /// Top-level Swift types this output writes.
    var topLevelTypeNames: [SwiftTypeIdentifier] { get }

    /// System types referenced by the generated source.
    var typeReferences: Set<SwiftTypeReference> { get }

    /// Writes this output, qualifying type references only when a declaration in `typeScope` shadows them.
    func write(using fileOutput: FileOutput, typeScope: SwiftTypeScope) async throws
}

extension APIOutput {
    func write(using fileOutput: FileOutput, typeScope: SwiftTypeScope) async throws {
        try await typeScope.qualify(source, references: typeReferences).write(
            to: configuration.output.api.directory.appending(
                path: relativePath,
                directoryHint: .notDirectory
            ),
            using: fileOutput
        )
    }
}
