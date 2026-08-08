import Foundation

struct GeneratedTypeNameValidator {
    private struct NestedTypeSource {
        let description: String
        let responseKey: String?
    }

    private let outputPlan: CodegenOutputPlan
    private let schemaTypeNames: Set<SwiftTypeIdentifier>

    init(outputPlan: CodegenOutputPlan) {
        self.outputPlan = outputPlan
        self.schemaTypeNames = Set(outputPlan.schemaWriter.topLevelDeclarations.map(\.name))
    }

    func validate() throws {
        try validateTopLevelDeclarations()
        try validateSchemaEnumCaseNames()
        try validateDocumentScopes()
    }

    private var configuration: Configuration {
        outputPlan.configuration
    }

    private func validateTopLevelDeclarations() throws {
        var declarationByTypeName: [SwiftTypeIdentifier: GeneratedTypeDeclaration] = [:]
        for declaration in outputPlan.topLevelDeclarations {
            if let conflictingDeclaration = declarationByTypeName[declaration.name] {
                throw conflictingTopLevelDeclarationsError(
                    declaration,
                    conflictingDeclaration: conflictingDeclaration
                )
            }
            declarationByTypeName[declaration.name] = declaration
        }
    }

    private func validateSchemaEnumCaseNames() throws {
        guard let caseConversion = configuration.output.schema.enums.caseConversion else { return }
        for typePlan in outputPlan.schemaWriter.typePlans {
            guard case .enum(let `enum`) = typePlan else { continue }
            var graphQLValueByCaseName: [String: String] = [:]
            for enumValue in `enum`.ast.enumValues {
                let caseName = caseConversion.convert(enumValue.name)
                if let conflictingGraphQLValue = graphQLValueByCaseName[caseName] {
                    throw enumCaseNameConflictError(
                        enumName: `enum`.ast.name,
                        graphQLValue: enumValue.name,
                        conflictingGraphQLValue: conflictingGraphQLValue,
                        caseName: caseName
                    )
                }
                graphQLValueByCaseName[caseName] = enumValue.name
            }
        }
    }

    private func validateDocumentScopes() throws {
        for documentPlan in outputPlan.documentsWriter.documentPlans {
            for definition in documentPlan.definitions {
                switch definition {
                case .operation(let operation, _):
                    try validate(operation, in: documentPlan.document)
                case .fragment(let fragment, let includesSelectionSet, _):
                    guard includesSelectionSet else { continue }
                    try validateSelectionSet(
                        fragment.resolvedSelectionSet,
                        conformances: configuration.output.documents.fragments.conformances,
                        visibleNestedTypes: [:],
                        in: documentPlan.document.url
                    )
                }
            }
        }
    }

    private func validate(_ operation: ResolvedOperation, in document: Document) throws {
        var operationTypes = [
            SwiftTypeIdentifier.data: NestedTypeSource(
                description: "Generated operation response type: Data",
                responseKey: nil
            ),
        ]
        let variableDefinitions = operation.operation.ast.variableDefinitions ?? []
        if !variableDefinitions.isEmpty {
            operationTypes[.variables] = NestedTypeSource(
                description: "Generated operation variables type: Variables",
                responseKey: nil
            )
        }
        for variableDefinition in variableDefinitions {
            try validateReferences(
                generatedTypeReferences(in: variableDefinition.type.typeName),
                shadowedBy: operationTypes,
                source: "Operation variable: \(variableDefinition.variable.name.value)",
                documentURL: document.url
            )
        }
        try validateSelectionSet(
            operation.resolvedSelectionSet,
            conformances: configuration.output.documents.operations.responseData.conformances,
            visibleNestedTypes: operationTypes,
            in: document.url
        )
    }

    private func validateSelectionSet(
        _ selectionSet: ResolvedSelectionSet,
        conformances: [String],
        visibleNestedTypes: [SwiftTypeIdentifier: NestedTypeSource],
        in documentURL: URL
    ) throws {
        let typePlan = SelectionSetTypePlan(selectionSet: selectionSet, conformances: conformances)
        var localTypes: [SwiftTypeIdentifier: NestedTypeSource] = [:]
        for declaration in typePlan.declarations {
            switch declaration.origin {
            case .codingKeys:
                if let conflictingSource = localTypes[declaration.name],
                   let responseKey = conflictingSource.responseKey {
                    throw responseKeyGeneratedTypeConflictError(
                        responseKey: responseKey,
                        typeName: declaration.name,
                        documentURL: documentURL
                    )
                }
                localTypes[declaration.name] = NestedTypeSource(
                    description: "Generated CodingKeys type",
                    responseKey: nil
                )
            case .responseKey(let responseKey):
                if let conflictingSource = localTypes[declaration.name],
                   let conflictingResponseKey = conflictingSource.responseKey {
                    throw conflictingFieldsError(
                        responseKey: responseKey,
                        conflictingResponseKey: conflictingResponseKey,
                        typeName: declaration.name,
                        documentURL: documentURL
                    )
                }
                localTypes[declaration.name] = NestedTypeSource(
                    description: "Response key: \(responseKey)",
                    responseKey: responseKey
                )
            }
        }
        if localTypes[.codingKeys] != nil, schemaTypeNames.contains(.codingKey) {
            throw schemaTypeReferenceConflictError(
                schemaTypeName: .codingKey,
                source: "Generated CodingKeys conformance",
                documentURL: documentURL
            )
        }
        let typesVisibleInScope = visibleNestedTypes.merging(localTypes) { _, local in local }
        for (responseKey, selection) in selectionSet {
            switch selection {
            case .field(let field, _):
                try validateReferences(
                    generatedTypeReferences(in: field.type),
                    shadowedBy: typesVisibleInScope,
                    source: "Response key: \(responseKey)",
                    documentURL: documentURL
                )
            case .fragmentSpread(let fragmentName, _):
                let typeName = SwiftTypeIdentifier(capitalizing: fragmentName)
                if let conflictingSource = typesVisibleInScope[typeName] {
                    if let responseKey = conflictingSource.responseKey {
                        throw fieldFragmentConflictError(
                            responseKey: responseKey,
                            fragmentName: fragmentName,
                            typeName: typeName,
                            documentURL: documentURL
                        )
                    }
                    throw generatedReferenceConflictError(
                        reference: typeName,
                        source: "Fragment: \(fragmentName)",
                        conflictingSource: conflictingSource,
                        documentURL: documentURL
                    )
                }
            }
        }
        for field in typePlan.fields {
            guard let nestedSelectionSet = field.type.unwrappedMap() else { continue }
            try validateSelectionSet(
                nestedSelectionSet,
                conformances: conformances,
                visibleNestedTypes: typesVisibleInScope,
                in: documentURL
            )
        }
    }

    private func validateReferences(
        _ references: Set<SwiftTypeIdentifier>,
        shadowedBy declarations: [SwiftTypeIdentifier: NestedTypeSource],
        source: String,
        documentURL: URL
    ) throws {
        for reference in references {
            guard let conflictingSource = declarations[reference] else { continue }
            throw generatedReferenceConflictError(
                reference: reference,
                source: source,
                conflictingSource: conflictingSource,
                documentURL: documentURL
            )
        }
    }

    private func generatedTypeReferences(in type: ResolvedFieldType) -> Set<SwiftTypeIdentifier> {
        switch type {
        case .scalar(let typeName, let isEnum):
            let typeName = lookupTypeName(in: typeName)
            var references: Set<SwiftTypeIdentifier> = []
            if schemaTypeNames.contains(typeName) {
                references.insert(typeName)
            }
            if isEnum {
                references.insert(SwiftTypeIdentifier(swiftName: "GraphQLEnum"))
            }
            return references
        case .map:
            return []
        case .list(let innerType), .optional(let innerType):
            return generatedTypeReferences(in: innerType)
        }
    }

    private func generatedTypeReferences(in type: SourceTypeName) -> Set<SwiftTypeIdentifier> {
        var references: Set<SwiftTypeIdentifier> = []
        _ = type.formatted { name in
            let typeName = lookupTypeName(in: name)
            if schemaTypeNames.contains(typeName) {
                references.insert(typeName)
            }
            return name
        }
        return references
    }

    private func lookupTypeName(in source: String) -> SwiftTypeIdentifier {
        let name = source.split(separator: ".", maxSplits: 1).first.map(String.init) ?? source
        return SwiftTypeIdentifier(swiftName: name)
    }

    private func conflictingTopLevelDeclarationsError(
        _ declaration: GeneratedTypeDeclaration,
        conflictingDeclaration: GeneratedTypeDeclaration
    ) -> Codegen.Error {
        Codegen.Error(description: """
        Generated GraphQL definitions produce conflicting top-level Swift type names.
        Definitions:
        \(conflictingDeclaration.origin)
        \(declaration.origin)
        Swift type name: \(declaration.name.source)

        \(declaration.origin.resolution)
        """)
    }

    private func enumCaseNameConflictError(
        enumName: String,
        graphQLValue: String,
        conflictingGraphQLValue: String,
        caseName: String
    ) -> Codegen.Error {
        Codegen.Error(description: """
        GraphQL enum values produce conflicting Swift case names after case conversion.
        Enum: \(enumName)
        GraphQL values:
        \(conflictingGraphQLValue)
        \(graphQLValue)
        Swift case name: \(identifier(caseName))

        Change the enum case conversion or rename the GraphQL enum values so the generated case names are distinct.
        """)
    }

    private func conflictingFieldsError(
        responseKey: String,
        conflictingResponseKey: String,
        typeName: SwiftTypeIdentifier,
        documentURL: URL
    ) -> Codegen.Error {
        Codegen.Error(description: """
        GraphQL response keys produce conflicting Swift nested type names.
        Response keys:
        \(conflictingResponseKey)
        \(responseKey)
        Swift type name: \(typeName.source)
        File: \(documentURL)

        Use a GraphQL field alias to give one of these fields a response key that produces a distinct Swift type name.
        """)
    }

    private func fieldFragmentConflictError(
        responseKey: String,
        fragmentName: String,
        typeName: SwiftTypeIdentifier,
        documentURL: URL
    ) -> Codegen.Error {
        Codegen.Error(description: """
        A GraphQL response key and fragment name produce conflicting Swift type names.
        Response key: \(responseKey)
        Fragment: \(fragmentName)
        Swift type name: \(typeName.source)
        File: \(documentURL)

        Use a GraphQL field alias or rename the fragment so they produce distinct Swift type names.
        """)
    }

    private func generatedReferenceConflictError(
        reference: SwiftTypeIdentifier,
        source: String,
        conflictingSource: NestedTypeSource,
        documentURL: URL
    ) -> Codegen.Error {
        Codegen.Error(description: """
        A generated nested Swift type shadows a type referenced by generated code.
        \(conflictingSource.description)
        Reference source: \(source)
        Swift type name: \(reference.source)
        File: \(documentURL)

        Use a GraphQL field alias or rename the referenced GraphQL definition so the generated names are distinct.
        """)
    }

    private func responseKeyGeneratedTypeConflictError(
        responseKey: String,
        typeName: SwiftTypeIdentifier,
        documentURL: URL
    ) -> Codegen.Error {
        Codegen.Error(description: """
        A GraphQL response key conflicts with a generated Swift type name.
        Response key: \(responseKey)
        Swift type name: \(typeName.source)
        File: \(documentURL)

        Use a GraphQL field alias that does not shadow a generated Swift type.
        """)
    }

    private func schemaTypeReferenceConflictError(
        schemaTypeName: SwiftTypeIdentifier,
        source: String,
        documentURL: URL
    ) -> Codegen.Error {
        Codegen.Error(description: """
        A generated schema type shadows a type referenced by generated code.
        Schema type: \(schemaTypeName.source)
        Reference source: \(source)
        File: \(documentURL)
        """)
    }
}
