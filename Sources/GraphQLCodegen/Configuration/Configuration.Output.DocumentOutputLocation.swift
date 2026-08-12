import Foundation

extension Configuration.Output {
    public enum DocumentOutputLocation: Sendable {
        /// Places each generated Swift document in the same directory as its definition.
        ///
        /// On each run, Codegen removes obsolete files ending in `.graphql.swift` from the configured
        /// document directories. Do not use that suffix for independently maintained files in those directories.
        case definition

        /// Places generated Swift documents in a separate directory.
        ///
        /// GraphQL document filenames must be unique across all configured document directories.
        /// On each run, Codegen removes obsolete files ending in `.graphql.swift` while preserving other files.
        /// Do not use that suffix for independently maintained files in this directory.
        case directory(URL)
    }
}
