import Foundation
import GraphQLCodegen

extension ExecutableConfigurationFile {
    /// Converts this file representation into a configuration, resolving relative file URLs.
    func configuration(relativeTo directory: URL, outputDirectory: URL? = nil) throws -> Configuration {
        let schemaSource: Configuration.Input.SchemaSource
        if input.schemaSource.scheme != nil, !input.schemaSource.isFileURL {
            schemaSource = .introspectionEndpoint(
                url: input.schemaSource,
                headers: input.schemaHeaders ?? [:]
            )
        } else {
            let url = try resolveSchemaURL(relativeTo: directory)
            schemaSource = url.pathExtension.lowercased() == "json"
                ? .JSONSchemaFile(url)
                : .SDLSchemaFile(url)
        }

        var configuredInput = try Configuration.Input.input(
            schemaSource: schemaSource,
            documentDirectories: resolveDocumentDirectories(relativeTo: directory)
        )
        if let deprecationPolicy = input.deprecationPolicy {
            configuredInput.deprecationPolicy = try Self.deprecationPolicy(deprecationPolicy)
        }

        var configuredOutput = try Configuration.Output.output(
            schema: schemaConfiguration(relativeTo: directory, outputDirectory: outputDirectory),
            support: supportConfiguration(relativeTo: directory, outputDirectory: outputDirectory)
        )
        if let indentation = output.indentation {
            switch indentation.style {
            case .spaces:
                guard let count = indentation.count else {
                    throw ConfigurationError(description: "Space indentation requires an indentation count.")
                }
                configuredOutput.indentation = .spaces(count)
            case .tab:
                configuredOutput.indentation = .tab
            }
        }
        if let documents = output.documents {
            configuredOutput.documents = try documentsConfiguration(
                documents,
                relativeTo: directory,
                outputDirectory: outputDirectory
            )
        } else if let outputDirectory {
            configuredOutput.documents.directory = .directory(outputDirectory)
        }

        return .configuration(input: configuredInput, output: configuredOutput)
    }

    private func resolveOutputDirectory(
        _ configuredDirectory: URL?,
        relativeTo directory: URL,
        override outputDirectory: URL?,
        parameter: String
    ) throws -> URL? {
        guard let configuredDirectory else {
            return outputDirectory
        }
        let resolvedDirectory = try resolveRelativeURL(
            configuredDirectory,
            relativeTo: directory,
            parameter: parameter,
            directoryHint: .isDirectory
        )
        return outputDirectory ?? resolvedDirectory
    }

    private func schemaConfiguration(
        relativeTo directory: URL,
        outputDirectory: URL?
    ) throws -> Configuration.Output.Schema {
        guard let schemaDirectory = try resolveOutputDirectory(
            output.schema.directory,
            relativeTo: directory,
            override: outputDirectory,
            parameter: "output.schema.directory"
        )
        else {
            throw ConfigurationError(description: "Missing required output directory: output.schema.directory")
        }
        var schema = Configuration.Output.Schema.schema(directory: schemaDirectory)
        if let header = output.schema.header {
            schema.header = header
        }
        if output.schema.includeHeader == false {
            schema.header = nil
        }
        if let importedModules = output.schema.importedModules {
            schema.importedModules = importedModules
        }
        if let scalarMapping = output.schema.scalars?.scalarMapping {
            schema.scalars.scalarMapping = scalarMapping.mapValues { scalar in
                let module = scalar.module.map { module in
                    var configuredModule = Configuration.Output.Schema.Scalars.Scalar.Module.module(
                        name: module.name
                    )
                    if let prefix = module.prefix {
                        configuredModule.prefix = prefix
                    }
                    return configuredModule
                }
                return .scalar(typeName: scalar.typeName, module: module)
            }
        }
        if let enums = output.schema.enums {
            if let conformances = enums.conformances {
                schema.enums.conformances = conformances
            }
            if let caseConversion = enums.caseConversion {
                schema.enums.caseConversion = try .conversion(
                    from: Self.casing(caseConversion.from),
                    to: Self.casing(caseConversion.to)
                )
            }
        }
        if let inputObjects = output.schema.inputObjects {
            if let immutable = inputObjects.immutable {
                schema.inputObjects.immutable = immutable
            }
            if let conformances = inputObjects.conformances {
                schema.inputObjects.conformances = conformances
            }
        }
        if let accessLevel = output.schema.accessLevel {
            schema.accessLevel = try Self.accessLevel(accessLevel)
        }
        return schema
    }

    private func documentsConfiguration(
        _ configuredDocuments: Output.Documents,
        relativeTo directory: URL,
        outputDirectory: URL?
    ) throws -> Configuration.Output.Documents {
        var documents = Configuration.Output.Documents.documents()
        if let documentDirectory = try resolveOutputDirectory(
            configuredDocuments.directory,
            relativeTo: directory,
            override: outputDirectory,
            parameter: "output.documents.directory"
        ) {
            documents.directory = .directory(documentDirectory)
        }
        if let header = configuredDocuments.header {
            documents.header = header
        }
        if configuredDocuments.includeHeader == false {
            documents.header = nil
        }
        if let importedModules = configuredDocuments.importedModules {
            documents.importedModules = importedModules
        }
        if let operations = configuredDocuments.operations {
            if let immutableExtensions = operations.immutableExtensions {
                documents.operations.immutableExtensions = immutableExtensions
            }
            if let immutableVariables = operations.immutableVariables {
                documents.operations.immutableVariables = immutableVariables
            }
            if let minifyDocument = operations.minifyDocument {
                documents.operations.minifyDocument = minifyDocument
            }
            if let conformances = operations.conformances {
                documents.operations.conformances = conformances
            }
            if let variables = operations.variables {
                if let immutable = variables.immutable {
                    documents.operations.variables.immutable = immutable
                }
                if let conformances = variables.conformances {
                    documents.operations.variables.conformances = conformances
                }
            }
            if let responseData = operations.responseData {
                if let immutable = responseData.immutable {
                    documents.operations.responseData.immutable = immutable
                }
                if let conformances = responseData.conformances {
                    documents.operations.responseData.conformances = conformances
                }
            }
        }
        if let fragments = configuredDocuments.fragments {
            if let immutable = fragments.immutable {
                documents.fragments.immutable = immutable
            }
            if let conformances = fragments.conformances {
                documents.fragments.conformances = conformances
            }
        }
        if let accessLevel = configuredDocuments.accessLevel {
            documents.accessLevel = try Self.accessLevel(accessLevel)
        }
        if let memberwiseInitializer = configuredDocuments.memberwiseInitializer {
            documents.memberwiseInitializer = memberwiseInitializer
        }
        return documents
    }

    private func supportConfiguration(
        relativeTo directory: URL,
        outputDirectory: URL?
    ) throws -> Configuration.Output.Support {
        guard let supportDirectory = try resolveOutputDirectory(
            output.support.directory,
            relativeTo: directory,
            override: outputDirectory,
            parameter: "output.support.directory"
        )
        else {
            throw ConfigurationError(description: "Missing required output directory: output.support.directory")
        }
        var support = Configuration.Output.Support.support(directory: supportDirectory)
        if let header = output.support.header {
            support.header = header
        }
        if output.support.includeHeader == false {
            support.header = nil
        }
        if let accessLevel = output.support.accessLevel {
            support.accessLevel = try Self.accessLevel(accessLevel)
        }
        if let httpSupport = output.support.httpSupport {
            if httpSupport.enabled == false {
                support.HTTPSupport = nil
            } else {
                var configuredHTTPSupport = Configuration.Output.Support.HTTPSupport.httpSupport()
                if let enableGETQueries = httpSupport.enableGETQueries {
                    configuredHTTPSupport.enableGETQueries = enableGETQueries
                }
                if let persistedOperations = httpSupport.persistedOperations {
                    switch persistedOperations.strategy {
                    case .automatic:
                        configuredHTTPSupport.persistedOperations = .automatic
                    case .disabled:
                        configuredHTTPSupport.persistedOperations = nil
                    case .registered:
                        if let allowUnregisteredOperations = persistedOperations.allowUnregisteredOperations {
                            configuredHTTPSupport.persistedOperations = .registered(
                                allowUnregisteredOperations: allowUnregisteredOperations
                            )
                        } else {
                            configuredHTTPSupport.persistedOperations = .registered()
                        }
                    }
                }
                if let subscriptionSupport = httpSupport.subscriptionSupport {
                    configuredHTTPSupport.subscriptionSupport = subscriptionSupport
                }
                support.HTTPSupport = configuredHTTPSupport
            }
        }
        return support
    }

    private static func deprecationPolicy(_ value: String) throws -> Configuration.Input.DeprecationPolicy {
        switch value {
        case "include":
            .include
        case "exclude":
            .exclude
        default:
            throw ConfigurationError(description: "Unsupported deprecation policy: \(value)")
        }
    }

    private static func accessLevel(_ value: String) throws -> Configuration.Output.AccessLevel {
        switch value {
        case "internal":
            .internal
        case "public":
            .public
        default:
            throw ConfigurationError(description: "Unsupported access level: \(value)")
        }
    }

    private static func casing(
        _ value: String
    ) throws -> Configuration.Output.Schema.Enums.CaseConversion.Case {
        switch value {
        case "lowerCamel":
            .lowerCamel
        case "macro":
            .macro
        default:
            throw ConfigurationError(description: "Unsupported enum case conversion: \(value)")
        }
    }
}
