import Foundation
import OrderedCollections

struct OperationBuilder {
    let configuration: Configuration
    let document: Document
    let resolvedOperation: ResolvedOperation
    let typeName: SwiftTypeIdentifier

    private var operation: Document.Operation {
        resolvedOperation.operation
    }

    private var isPublic: Bool {
        switch configuration.output.documents.accessLevel {
        case .internal: false
        case .public: true
        }
    }

    func buildable() throws -> SwiftTypeBuildable {
        var operationStruct = makeOperationStruct()
        addOperationNameProperty(to: &operationStruct)
        addDocumentProperty(to: &operationStruct)
        addHashProperty(to: &operationStruct)
        addVariablesProperty(to: &operationStruct)
        addExtensionsProperty(to: &operationStruct)
        addVariablesStruct(to: &operationStruct)
        try addDataStruct(to: &operationStruct)
        return operationStruct
    }

    private func makeOperationStruct() -> SwiftStructBuilder {
        var conformances = configuration.output.documents.operations.conformances
        if configuration.output.api.HTTPSupport != nil {
            switch operation.ast.operation {
            case .query: conformances.append("GraphQLQuery")
            case .mutation: conformances.append("GraphQLMutation")
            case .subscription: conformances.append("GraphQLSubscription")
            }
        }
        return SwiftStructBuilder(
            description: nil,
            isPublic: isPublic,
            name: typeName.source,
            conformances: conformances
        )
    }

    private func addOperationNameProperty(to operationStruct: inout SwiftStructBuilder) {
        let value =
            if let operationName = operation.ast.name?.value {
                "\"\(operationName)\""
            } else {
                "nil"
            }
        operationStruct.addProperty(
            description: nil,
            deprecation: nil,
            isPublic: isPublic,
            isStatic: true,
            immutable: true,
            name: "operationName",
            value: .assigned(
                value,
                type: "String?"
            )
        )
    }

    private func addDocumentProperty(to operationStruct: inout SwiftStructBuilder) {
        switch configuration.output.documents.operations.persistedOperations {
        case .registered: break
        case .automatic, .none:
            operationStruct.addProperty(
                description: nil,
                deprecation: nil,
                isPublic: isPublic,
                isStatic: true,
                immutable: true,
                name: "document",
                value: .assigned(SwiftSource(value: operation.documentText).multilineStringLiteral, type: nil)
            )
            operationStruct.addProperty(
                description: nil,
                deprecation: nil,
                isPublic: isPublic,
                isStatic: true,
                immutable: true,
                name: "minifiedDocument",
                value: .assigned(
                    SwiftSource(
                        value: operation.canonicalText
                    ).multilineStringLiteral,
                    type: nil
                )
            )
        }
    }

    private func addHashProperty(to operationStruct: inout SwiftStructBuilder) {
        switch operation.persistence {
        case .registered(let hash):
            operationStruct.addProperty(
                description: nil,
                deprecation: nil,
                isPublic: isPublic,
                isStatic: true,
                immutable: true,
                name: "hash",
                value: .assigned("\"\(hash)\"", type: nil)
            )
        case .standard: break
        }
    }

    private func addExtensionsProperty(to operationStruct: inout SwiftStructBuilder) {
        operationStruct.addProperty(
            description: nil,
            deprecation: nil,
            isPublic: isPublic,
            isStatic: false,
            immutable: configuration.output.documents.operations.immutableExtensions,
            name: "extensions",
            value: .unassigned(
                type: "[String: AnyEncodable]?",
                initialized: .direct(defaultValue: "nil")
            )
        )
    }

    private func addVariablesProperty(to operationStruct: inout SwiftStructBuilder) {
        let variableDefinitions = operation.ast.variableDefinitions
        guard !variableDefinitions.isEmpty else {
            operationStruct.addProperty(
                description: nil,
                deprecation: nil,
                isPublic: isPublic,
                isStatic: false,
                immutable: true,
                name: "variables",
                value: .assigned(
                    "nil",
                    type: "Never?"
                )
            )
            return
        }
        let typeNames = variableDefinitions.map(\.typeName)
        operationStruct.addProperty(
            description: nil,
            deprecation: nil,
            isPublic: isPublic,
            isStatic: false,
            immutable: configuration.output.documents.operations.immutableVariables,
            name: "variables",
            value: .unassigned(
                type: SwiftTypeIdentifier.variables.source,
                initialized: .flattened(
                    variableDefinitions.enumerated().map { idx, variableDefinition in
                        .named(
                            variableDefinition.variable.name.value,
                            type: typeNames[idx],
                            defaultValue: {
                                switch variableDefinition.type.typeName {
                                case .optional:
                                    if let defaultValue = variableDefinition.defaultValue {
                                        "nil \(SwiftSource(value: defaultValue.description).blockComment)"
                                    } else {
                                        "nil"
                                    }
                                case .list, .name:
                                    if let defaultValue = variableDefinition.defaultValue {
                                        ".useDefault \(SwiftSource(value: defaultValue.description).blockComment)"
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

    private func addVariablesStruct(to operationStruct: inout SwiftStructBuilder) {
        let variableDefinitions = operation.ast.variableDefinitions
        guard !variableDefinitions.isEmpty else { return }
        let typeNames = variableDefinitions.map(\.typeName)
        var variablesStruct = SwiftStructBuilder(
            description: nil,
            isPublic: isPublic,
            name: SwiftTypeIdentifier.variables.source,
            conformances: configuration.output.documents.operations.variables.conformances
        )
        for (idx, variableDefinition) in variableDefinitions.enumerated() {
            variablesStruct.addProperty(
                description: nil,
                deprecation: nil,
                isPublic: isPublic,
                isStatic: false,
                immutable: configuration.output.documents.operations.variables.immutable,
                name: variableDefinition.variable.name.value,
                value: .unassigned(type: typeNames[idx], initialized: nil)
            )
        }
        operationStruct.addNestedType(variablesStruct)
    }

    private func addDataStruct(to operationStruct: inout SwiftStructBuilder) throws {
        var structBuilder = SwiftStructBuilder(
            description: nil,
            isPublic: isPublic,
            name: SwiftTypeIdentifier.data.source,
            conformances: configuration.output.documents.operations.responseData.conformances
        )
        do {
            try structBuilder.addSelectionSet(
                resolvedOperation.resolvedSelectionSet,
                immutable: configuration.output.documents.operations.responseData.immutable,
                isPublic: isPublic,
                conformances: OrderedSet(configuration.output.documents.operations.responseData.conformances),
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

extension GraphQLAST.VariableDefinition {
    fileprivate var typeName: String {
        type.typeName.inputTypeName(hasDefaultValue: defaultValue != nil)
    }
}
