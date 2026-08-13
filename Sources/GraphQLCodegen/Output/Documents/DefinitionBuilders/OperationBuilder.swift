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
        addVariablesProperty(to: &operationStruct)
        addResponseDecodingContextProperty(to: &operationStruct)
        addExtensionsProperty(to: &operationStruct)
        addVariablesStruct(to: &operationStruct)
        try addDataStruct(to: &operationStruct)
        return operationStruct
    }

    private func makeOperationStruct() -> SwiftStructBuilder {
        var conformances = configuration.output.documents.operations.conformances
        if configuration.output.support.HTTPSupport != nil {
            switch operation.ast.operation {
            case .query: conformances.append("GraphQLQuery")
            case .mutation: conformances.append("GraphQLMutation")
            case .subscription: conformances.append("GraphQLSubscription")
            }
        }
        return SwiftStructBuilder(
            description: operation.ast.description?.value,
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
        let documentText =
            if configuration.output.documents.operations.minifyDocument {
                operation.canonicalText
            } else {
                operation.documentText
            }
        operationStruct.addProperty(
            description: nil,
            deprecation: nil,
            isPublic: isPublic,
            isStatic: true,
            immutable: true,
            name: "document",
            value: .assigned(
                SwiftSource(value: documentText).multilineStringLiteral,
                type: nil
            )
        )
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

    private func addResponseDecodingContextProperty(to operationStruct: inout SwiftStructBuilder) {
        guard resolvedOperation.requiresResponseDecodingContext else { return }
        let directiveVariables = (operation.ast.variableDefinitions ?? []).filter { definition in
            resolvedOperation.fragmentDirectiveVariableNames.contains(definition.variable.name.value)
        }
        operationStruct.addProperty(
            description: "Effective Boolean variables used to decode conditional fragment spreads.",
            deprecation: nil,
            isPublic: isPublic,
            isStatic: false,
            immutable: true,
            name: "responseDecodingContext",
            value: .computed(
                responseDecodingContextSource(for: directiveVariables),
                type: "GraphQLResponseDecodingContext"
            )
        )
    }

    private func responseDecodingContextSource(for directiveVariables: [GraphQLAST.VariableDefinition]) -> String {
        let hasOnlyRequiredVariables = directiveVariables.allSatisfy { variable in
            guard case .name("Bool") = variable.type.typeName else { return false }
            return variable.defaultValue == nil
        }
        if hasOnlyRequiredVariables {
            let entries = directiveVariables.map { variable in
                let name = variable.variable.name.value
                return "\(SwiftSource(value: name).singleLineStringLiteral): variables.\(identifier(name))"
            }
            return "GraphQLResponseDecodingContext(directiveVariables: [\(entries.joined(separator: ", "))])"
        }
        let indentation = configuration.output.indentation.string
        var lines = [
            "GraphQLResponseDecodingContext(directiveVariables: {",
            "\(indentation)var directiveVariables: [String: Bool] = [:]",
        ]
        for variable in directiveVariables {
            let name = variable.variable.name.value
            let key = SwiftSource(value: name).singleLineStringLiteral
            let value = "variables.\(identifier(name))"
            switch variable.type.typeName {
            case .name("Bool"):
                if let defaultValue = variable.defaultValue {
                    lines.append("\(indentation)switch \(value) {")
                    lines.append("\(indentation)case .useDefault: directiveVariables[\(key)] = \(defaultValue.description)")
                    lines.append("\(indentation)case .value(let value): directiveVariables[\(key)] = value")
                    lines.append("\(indentation)}")
                } else {
                    lines.append("\(indentation)directiveVariables[\(key)] = \(value)")
                }
            case .optional(.name("Bool")):
                lines.append("\(indentation)switch \(value) {")
                if case .boolean(let defaultValue)? = variable.defaultValue {
                    lines.append("\(indentation)case .none: directiveVariables[\(key)] = \(defaultValue.value)")
                } else {
                    lines.append("\(indentation)case .none: break")
                }
                lines.append("\(indentation)case .some(.null): break")
                lines.append("\(indentation)case .some(.value(let value)): directiveVariables[\(key)] = value")
                lines.append("\(indentation)}")
            default: break
            }
        }
        lines.append("\(indentation)return directiveVariables")
        lines.append("}())")
        return lines.joined(separator: "\n")
    }

    private func addVariablesProperty(to operationStruct: inout SwiftStructBuilder) {
        let variableDefinitions = operation.ast.variableDefinitions ?? []
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
                    variableDefinitions.map { variableDefinition in
                        .init(
                            name: variableDefinition.variable.name.value,
                            type: variableDefinition.typeName,
                            description: variableDefinition.description?.value,
                            defaultValue: variableDefinition.type.typeName.inputDefaultValue(
                                variableDefinition.defaultValue?.description
                            )
                        )
                    },
                    indentation: configuration.output.indentation
                )
            )
        )
    }

    private func addVariablesStruct(to operationStruct: inout SwiftStructBuilder) {
        let variableDefinitions = operation.ast.variableDefinitions ?? []
        guard !variableDefinitions.isEmpty else { return }
        var variablesStruct = SwiftStructBuilder(
            description: nil,
            isPublic: isPublic,
            name: SwiftTypeIdentifier.variables.source,
            conformances: configuration.output.documents.operations.variables.conformances
        )
        for variableDefinition in variableDefinitions {
            variablesStruct.addProperty(
                description: variableDefinition.description?.value,
                deprecation: nil,
                isPublic: isPublic,
                isStatic: false,
                immutable: configuration.output.documents.operations.variables.immutable,
                name: variableDefinition.variable.name.value,
                value: .unassigned(type: variableDefinition.typeName, initialized: nil)
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
