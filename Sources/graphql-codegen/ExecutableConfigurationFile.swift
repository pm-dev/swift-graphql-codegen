import Foundation

/// The JSON representation accepted by the `graphql-codegen` executable.
///
/// ```json
/// {
///   "input": {
///     "schemaSource": "schema.graphqls",
///     "documentDirectories": ["GraphQL"]
///   },
///   "output": {
///     "schema": { "directory": "Generated/Schema" },
///     "documents": { "directory": "Generated/Documents" },
///     "support": {
///       "directory": "Generated/Support",
///       "httpSupport": {
///         "persistedOperations": {
///           "strategy": "registered",
///           "allowUnregisteredOperations": true
///         }
///       }
///     }
///   }
/// }
/// ```
///
/// All file and directory URLs must be relative to the directory containing the configuration file.
/// Remote introspection endpoints use absolute HTTP or HTTPS URLs.
/// Set `httpSupport.enabled` to `false` to disable HTTP support, or set
/// `persistedOperations.strategy` to `"disabled"` to send complete operation documents.
struct ExecutableConfigurationFile: Decodable, Sendable {
    struct Input: Decodable, Sendable {
        let schemaSource: URL
        let schemaHeaders: [String: String]?
        let documentDirectories: [URL]
        let deprecationPolicy: String?
    }

    struct Output: Decodable, Sendable {
        struct Indentation: Decodable, Sendable {
            enum Style: String, Decodable, Sendable {
                case spaces
                case tab
            }

            let style: Style
            let count: Int?
        }

        struct TypeOptions: Decodable, Sendable {
            let immutable: Bool?
            let conformances: [String]?
        }

        struct Schema: Decodable, Sendable {
            struct Scalars: Decodable, Sendable {
                struct Scalar: Decodable, Sendable {
                    struct Module: Decodable, Sendable {
                        let name: String
                        let prefix: Bool?
                    }

                    let typeName: String
                    let module: Module?
                }

                let scalarMapping: [String: Scalar]?
            }

            struct Enums: Decodable, Sendable {
                struct CaseConversion: Decodable, Sendable {
                    let from: String
                    let to: String
                }

                let conformances: [String]?
                let caseConversion: CaseConversion?
            }

            let directory: URL?
            let header: String?
            let includeHeader: Bool?
            let importedModules: [String]?
            let scalars: Scalars?
            let enums: Enums?
            let inputObjects: TypeOptions?
            let accessLevel: String?
        }

        struct Documents: Decodable, Sendable {
            struct Operations: Decodable, Sendable {
                let immutableExtensions: Bool?
                let immutableVariables: Bool?
                let minifyDocument: Bool?
                let conformances: [String]?
                let variables: TypeOptions?
                let responseData: TypeOptions?
            }

            let directory: URL?
            let header: String?
            let includeHeader: Bool?
            let importedModules: [String]?
            let operations: Operations?
            let fragments: TypeOptions?
            let accessLevel: String?
            let memberwiseInitializer: Bool?
        }

        struct Support: Decodable, Sendable {
            struct HTTPSupport: Decodable, Sendable {
                struct PersistedOperations: Decodable, Sendable {
                    enum Strategy: String, Decodable, Sendable {
                        case automatic
                        case registered
                        case disabled
                    }

                    let strategy: Strategy
                    let allowUnregisteredOperations: Bool?
                }

                let enabled: Bool?
                let enableGETQueries: Bool?
                let persistedOperations: PersistedOperations?
                let subscriptionSupport: Bool?
            }

            let directory: URL?
            let header: String?
            let includeHeader: Bool?
            let accessLevel: String?
            let httpSupport: HTTPSupport?
        }

        let indentation: Indentation?
        let schema: Schema
        let documents: Documents?
        let support: Support
    }

    let input: Input
    let output: Output
}

extension ExecutableConfigurationFile {
    struct ConfigurationError: Swift.Error, CustomStringConvertible {
        let description: String
    }

    static func at(_ url: URL) throws -> Self {
        try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }

    func resolveSchemaURL(relativeTo directory: URL) throws -> URL {
        try resolveRelativeURL(
            input.schemaSource,
            relativeTo: directory,
            parameter: "schemaSource",
            directoryHint: .notDirectory
        )
    }

    func resolveDocumentDirectories(relativeTo directory: URL) throws -> [URL] {
        try input.documentDirectories.map {
            try resolveRelativeURL(
                $0,
                relativeTo: directory,
                parameter: "documentDirectories",
                directoryHint: .isDirectory
            )
        }
    }

    func resolveRelativeURL(
        _ url: URL,
        relativeTo directory: URL,
        parameter: String,
        directoryHint: URL.DirectoryHint
    ) throws -> URL {
        guard url.scheme == nil, !url.path.hasPrefix("/") else {
            throw ConfigurationError(description: "\(parameter) must be relative to the configuration file: \(url)")
        }
        return directory.appending(path: url.path, directoryHint: directoryHint).standardizedFileURL
    }
}
