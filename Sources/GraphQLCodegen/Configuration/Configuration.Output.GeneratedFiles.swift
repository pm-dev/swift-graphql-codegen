import Foundation

extension Configuration.Output {
    /// Configuration that always generates exactly `GraphQLAPI.generated.swift`,
    /// `GraphQLDocuments.generated.swift`, and `GraphQLSchema.generated.swift`.
    public struct GeneratedFiles: Sendable {
        /// Creates deterministic output suitable for a SwiftPM build-tool plugin.
        ///
        /// Codegen assumes exclusive ownership of `directory` and replaces its contents on each run.
        public static func generatedFiles(
            directory: URL,
            indentation: Indentation = .spaces(4),
            schema: Schema = .schema(),
            documents: Documents = .documents(),
            api: API = .api()
        ) -> GeneratedFiles {
            GeneratedFiles(
                directory: directory,
                indentation: indentation,
                schema: schema,
                documents: documents,
                api: api
            )
        }

        public var directory: URL
        public var indentation: Indentation
        public var schema: Schema
        public var documents: Documents
        public var api: API

        /// The three paths a SwiftPM build command should declare as its output files.
        public var outputFiles: [URL] {
            Configuration.Output.GeneratedFile.allCases.map { file in
                directory.appending(path: file.rawValue, directoryHint: .notDirectory)
            }
        }

        var configurationOutput: Configuration.Output {
            Configuration.Output(
                indentation: indentation,
                schema: schema.output(directory: directory),
                documents: documents.output(directory: directory),
                api: api.output(directory: directory),
                layout: .generatedFiles(directory)
            )
        }
    }
}

extension Configuration.Output.GeneratedFiles {
    /// Options controlling the contents of `GraphQLSchema.generated.swift`.
    public struct Schema: Sendable {
        /// Creates schema-file configuration.
        public static func schema(
            header: String? = "// @generated",
            importedModules: [String] = [],
            scalarMappings: [String: String] = [:],
            enums: Enums = .enums(),
            inputObjects: InputObjects = .inputObjects(),
            accessLevel: Configuration.Output.AccessLevel = .internal
        ) -> Schema {
            Schema(
                header: header,
                importedModules: importedModules,
                scalarMappings: scalarMappings,
                enums: enums,
                inputObjects: inputObjects,
                accessLevel: accessLevel
            )
        }

        public var header: String?
        public var importedModules: [String]
        public var scalarMappings: [String: String]
        public var enums: Enums
        public var inputObjects: InputObjects
        public var accessLevel: Configuration.Output.AccessLevel

        func output(directory: URL) -> Configuration.Output.Schema {
            .schema(
                directory: directory,
                scalars: .init(
                    customization: .mappings(scalarMappings),
                    directoryName: nil,
                    header: header,
                    importedModules: importedModules
                ),
                enums: .enums(
                    directoryName: nil,
                    header: header,
                    importedModules: importedModules,
                    conformances: enums.conformances,
                    caseConversion: enums.caseConversion
                ),
                inputObjects: .inputObjects(
                    directoryName: nil,
                    header: header,
                    importedModules: importedModules,
                    immutable: inputObjects.immutable,
                    conformances: inputObjects.conformances
                ),
                accessLevel: accessLevel
            )
        }
    }
}

extension Configuration.Output.GeneratedFiles.Schema {
    /// Options controlling enums in the generated schema file.
    public struct Enums: Sendable {
        public static func enums(
            conformances: [String] = ["Encodable", "Sendable"],
            caseConversion: Configuration.Output.Schema.Enums.CaseConversion? = nil
        ) -> Enums {
            Enums(conformances: conformances, caseConversion: caseConversion)
        }

        public var conformances: [String]
        public var caseConversion: Configuration.Output.Schema.Enums.CaseConversion?
    }

    /// Options controlling input objects in the generated schema file.
    public struct InputObjects: Sendable {
        public static func inputObjects(
            immutable: Bool = true,
            conformances: [String] = ["Encodable", "Hashable", "Sendable"]
        ) -> InputObjects {
            InputObjects(immutable: immutable, conformances: conformances)
        }

        public var immutable: Bool
        public var conformances: [String]
    }
}

extension Configuration.Output.GeneratedFiles {
    /// Options controlling the contents of `GraphQLDocuments.generated.swift`.
    public struct Documents: Sendable {
        /// Creates document-file configuration.
        public static func documents(
            header: String? = "// @generated",
            importedModules: [String] = [],
            operations: Operations = .operations(),
            fragments: Configuration.Output.Documents.Fragments = .fragments(),
            accessLevel: Configuration.Output.AccessLevel = .internal,
            memberwiseInitializer: Bool = false
        ) -> Documents {
            Documents(
                header: header,
                importedModules: importedModules,
                operations: operations,
                fragments: fragments,
                accessLevel: accessLevel,
                memberwiseInitializer: memberwiseInitializer
            )
        }

        public var header: String?
        public var importedModules: [String]
        public var operations: Operations
        public var fragments: Configuration.Output.Documents.Fragments
        public var accessLevel: Configuration.Output.AccessLevel
        public var memberwiseInitializer: Bool

        func output(directory: URL) -> Configuration.Output.Documents {
            .documents(
                directory: .directory(directory),
                header: header,
                importedModules: importedModules,
                operations: operations.output,
                fragments: fragments,
                accessLevel: accessLevel,
                memberwiseInitializer: memberwiseInitializer
            )
        }
    }
}

extension Configuration.Output.GeneratedFiles.Documents {
    /// Options controlling operations in the generated documents file.
    public struct Operations: Sendable {
        public typealias Variables = Configuration.Output.Documents.Operations.Variables
        public typealias ResponseData = Configuration.Output.Documents.Operations.ResponseData

        /// Creates operation configuration without any additional file outputs.
        public static func operations(
            immutableExtensions: Bool = true,
            immutableVariables: Bool = true,
            minifyDocument: Bool = true,
            conformances: [String] = [],
            variables: Variables = .variables(),
            responseData: ResponseData = .responseData()
        ) -> Operations {
            Operations(
                immutableExtensions: immutableExtensions,
                immutableVariables: immutableVariables,
                minifyDocument: minifyDocument,
                conformances: conformances,
                variables: variables,
                responseData: responseData
            )
        }

        public var immutableExtensions: Bool
        public var immutableVariables: Bool
        public var minifyDocument: Bool
        public var conformances: [String]
        public var variables: Variables
        public var responseData: ResponseData

        var output: Configuration.Output.Documents.Operations {
            .operations(
                immutableExtensions: immutableExtensions,
                immutableVariables: immutableVariables,
                minifyDocument: minifyDocument,
                conformances: conformances,
                variables: variables,
                responseData: responseData
            )
        }
    }
}

extension Configuration.Output.GeneratedFiles {
    /// Options controlling the contents of `GraphQLAPI.generated.swift`.
    public struct API: Sendable {
        /// Creates API-file configuration.
        public static func api(
            header: String? = "// @generated",
            accessLevel: Configuration.Output.AccessLevel = .internal,
            HTTPSupport: Configuration.Output.API.HTTPSupport? = .httpSupport()
        ) -> API {
            API(header: header, accessLevel: accessLevel, HTTPSupport: HTTPSupport)
        }

        public var header: String?
        public var accessLevel: Configuration.Output.AccessLevel
        public var HTTPSupport: Configuration.Output.API.HTTPSupport?

        func output(directory: URL) -> Configuration.Output.API {
            .api(
                directory: directory,
                header: header,
                accessLevel: accessLevel,
                HTTPSupport: HTTPSupport
            )
        }
    }
}
