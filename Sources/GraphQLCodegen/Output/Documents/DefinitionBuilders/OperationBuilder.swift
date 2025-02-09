import Foundation
import OrderedCollections

struct OperationBuilder {
    let configuration: Configuration
    let document: Document
    let resolvedOperation: ResolvedOperation
    let resolvedDocuments: ResolvedDocuments

    private var operationStruct = SwiftStructBuilder()

    private var operation: Document.Operation {
        resolvedOperation.operation
    }

    init(
        configuration: Configuration,
        document: Document,
        resolvedOperation: ResolvedOperation,
        resolvedDocuments: ResolvedDocuments
    ) {
        self.configuration = configuration
        self.document = document
        self.resolvedOperation = resolvedOperation
        self.resolvedDocuments = resolvedDocuments
    }

    mutating func buildable() throws -> SwiftTypeBuildable {
        try startOperationStruct()
        addOperationNameProperty()
        try addDocumentProperty()
        addHashProperty()
        addVariablesProperty()
        addExtensionsProperty()
        addVariablesStruct()
        try addDataStruct()
        return operationStruct
    }

    private mutating func startOperationStruct() throws {
        let structName: String
        let operationType = operation.ast.operation.rawValue.capitalizedFirst
        if let name = operation.ast.name {
            structName = name.value + operationType
        } else {
            let operationCount = document.definitions.count { definition in
                switch definition {
                case .fragment: false
                case .operation: true
                }
            }
            guard operationCount == 1 else {
                throw Codegen.Error(description: """
                Missing operation name. Operations may only be unnamed if they're the only operation in the document.
                https://spec.graphql.org/October2021/#sel-FAFPTABABoC6of
                URL: \(document.url)
                """)
            }
            let fileName = document.url.deletingPathExtension().lastPathComponent
            structName = fileName.hasSuffix(operationType) ? fileName : fileName + operationType
        }
        var conformances = configuration.output.documents.operations.conformances
        if configuration.output.api.HTTPSupport != nil {
            switch operation.ast.operation {
            case .query:
                conformances.append("GraphQLQuery")
            case .mutation:
                conformances.append("GraphQLMutation")
            case .subscription:
                conformances.append("GraphQLSubscription")
            }
        }
        operationStruct.start(
            description: nil,
            isPublic: false,
            structName: structName,
            conformances: conformances
        )
    }

    private mutating func addOperationNameProperty() {
        let value =
            if let operationName = operation.ast.name?.value {
                "\"\(operationName)\""
            } else {
                "nil"
            }
        operationStruct.addProperty(
            description: nil,
            deprecation: nil,
            isPublic: false,
            isStatic: true,
            immutable: true,
            name: "operationName",
            value: .assigned(value, type: "String?")
        )
    }

    private mutating func addDocumentProperty() throws {
        switch configuration.output.documents.operations.persistedOperations {
        case .registered: break
        case .automatic, .none:
            let expandedSourceText = try OperationTextResolver(
                operation: operation,
                fragmentLookup: resolvedDocuments.fragmentLookup.mapValues(\.fragment)
            ).expandSourceText { fragment in "\\(\(fragment.ast.name.value.capitalizedFirst).source)" }
            operationStruct.addProperty(
                description: nil,
                deprecation: nil,
                isPublic: false,
                isStatic: true,
                immutable: true,
                name: "document",
                value: .assigned("\"\"\"\n\(expandedSourceText)\n\"\"\"", type: nil)
            )
        }
    }

    private mutating func addHashProperty() {
        if let hash = operation.hash {
            operationStruct.addProperty(
                description: nil,
                deprecation: nil,
                isPublic: false,
                isStatic: true,
                immutable: true,
                name: "hash",
                value: .assigned("\"\(hash)\"", type: nil)
            )
        }
    }

    private mutating func addExtensionsProperty() {
        operationStruct.addProperty(
            description: nil,
            deprecation: nil,
            isPublic: false,
            isStatic: false,
            immutable: configuration.output.documents.operations.immutableExtensions,
            name: "extensions",
            value: .unassigned(
                type: "[String: AnyEncodable]?",
                initialized: .direct(defaultValue: "nil")
            )
        )
    }

    private mutating func addVariablesProperty() {
        let variableDefinitions = operation.ast.variableDefinitions
        guard !variableDefinitions.isEmpty else {
            operationStruct.addProperty(
                description: nil,
                deprecation: nil,
                isPublic: false,
                isStatic: false,
                immutable: true,
                name: "variables",
                value: .assigned("nil", type: "Never?")
            )
            return
        }
        let typeNames = variableDefinitions.map(\.typeName)
        operationStruct.addProperty(
            description: nil,
            deprecation: nil,
            isPublic: false,
            isStatic: false,
            immutable: configuration.output.documents.operations.immutableVariables,
            name: "variables",
            value: .unassigned(
                type: "Variables",
                initialized: .flattened(
                    variableDefinitions.enumerated().map { idx, variableDefinition in
                        .named(
                            variableDefinition.variable.name.value,
                            type: typeNames[idx],
                            defaultValue: {
                                switch variableDefinition.type.typeName {
                                case .optional:
                                    if let defaultValue = variableDefinition.defaultValue {
                                        ".value(.useDefault) /* \(defaultValue.description) */"
                                    } else {
                                        "nil"
                                    }
                                case .list, .name:
                                    if let defaultValue = variableDefinition.defaultValue {
                                        ".useDefault /* \(defaultValue.description) */"
                                    } else {
                                        nil
                                    }
                                }
                            }()
                        )
                    },
                    indentation: configuration.output.indentation
                )
            )
        )
    }

    private mutating func addVariablesStruct() {
        let variableDefinitions = operation.ast.variableDefinitions
        guard !variableDefinitions.isEmpty else { return }
        let typeNames = variableDefinitions.map(\.typeName)
        var variablesStruct = SwiftStructBuilder()
        variablesStruct.start(
            description: nil,
            isPublic: false,
            structName: "Variables",
            conformances: configuration.output.documents.operations.variables.conformances
        )
        for (idx, variableDefinition) in variableDefinitions.enumerated() {
            variablesStruct.addProperty(
                description: nil,
                deprecation: nil,
                isPublic: false,
                isStatic: false,
                immutable: configuration.output.documents.operations.variables.immutable,
                name: variableDefinition.variable.name.value,
                value: .unassigned(type: typeNames[idx], initialized: nil)
            )
        }
        operationStruct.addNestedType(variablesStruct)
    }

    private mutating func addDataStruct() throws {
        var structBuilder = SwiftStructBuilder()
        structBuilder.start(
            description: nil,
            isPublic: false,
            structName: "Data",
            conformances: configuration.output.documents.operations.responseData.conformances
        )
        do {
            try structBuilder.addSelectionSet(
                resolvedOperation.resolvedSelectionSet,
                immutable: configuration.output.documents.operations.responseData.immutable,
                isPublic: false,
                conformances: configuration.output.documents.operations.responseData.conformances,
                configuration: configuration
            )
        } catch {
            switch error as? SelectionSetError {
            case .fragmentSpreadNeedsTypename(let fragmentSpread):
                throw Codegen.Error(description: """
                \(document.url)
                '__typename' needed on operation '\(operation.ast.name?.value ?? "")'.
                In order to resolve the fragment spread '...\(fragmentSpread)', '__typename' is needed at the top level.
                Codegen never modifies your GraphQL documents, so please add '__typename' for this case.
                """)
            case .selectionSetNeedsTypename(let field, let fragmentSpread):
                throw Codegen.Error(description: """
                \(document.url)
                '__typename' needed in selection set under the '\(field)' field.
                In order to resolve the fragment spread '...\(fragmentSpread)', '__typename' is needed at the same level.
                Codegen never modifies your GraphQL documents, so please add '__typename' for this case.
                """)
            case .none: throw error
            }
        }
        operationStruct.addNestedType(structBuilder)
    }
}

extension AST.VariableDefinition {
    fileprivate var typeName: String {
        type.typeName.formatted(
            formatName: { defaultValue == nil ? $0 : "GraphQLHasDefault<\($0)>" },
            formatOptional: { "GraphQLNullable<\($0)>?" }
        )
    }
}
