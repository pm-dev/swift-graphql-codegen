import Foundation

struct GeneratedTypeNameValidator {
    private struct NestedTypeSource {
        let description: String
        let responseKey: String?
    }

    private let outputPlan: CodegenOutputPlan
    private let topLevelTypeNames: Set<SwiftTypeIdentifier>

    init(outputPlan: CodegenOutputPlan) {
        self.outputPlan = outputPlan
        self.topLevelTypeNames = Set(outputPlan.topLevelDeclarations.map(\.name))
    }

    func validate() throws {
        try validateTopLevelDeclarations()
        try validateSchemaScopes()
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
            try validateReservedTypeName(
                typeName: declaration.name,
                reservedTypeNames: outputPlan.reservedTopLevelTypeNames,
                source: declaration.origin.description,
                resolution: declaration.origin.resolution,
                documentURL: nil
            )
            declarationByTypeName[declaration.name] = declaration
        }
    }

    private func validateSchemaScopes() throws {
        for typePlan in outputPlan.schemaWriter.typePlans {
            guard case .inputObject(let inputObject) = typePlan,
                  !inputObject.ast.inputFields.isEmpty else {
                continue
            }
            let conformances = outputPlan.schemaWriter.conformances(for: typePlan)
            guard conformances.contains(where: {
                SwiftConformanceName(source: $0).usesCodingKeys
            }) else {
                continue
            }
            let name = inputObject.ast.name
            let codingKeys = NestedTypeSource(
                description: "Generated CodingKeys for schema type: \(name)",
                responseKey: nil
            )
            let declarations = [SwiftTypeIdentifier.codingKeys: codingKeys]
            for inputField in inputObject.ast.inputFields {
                let references = typeReferences(in: inputField.type.swiftName)
                try validateReferences(
                    references,
                    shadowedBy: declarations,
                    source: "Schema input field: \(inputField.name)",
                    documentURL: nil
                )
            }
        }
    }

    private func validateDocumentScopes() throws {
        for documentPlan in outputPlan.documentsWriter.documentPlans {
            for definition in documentPlan.definitions {
                switch definition {
                case .operation(let operation, _):
                    try validate(operation, in: documentPlan.document)
                case .fragment(let fragment, let includesSelectionSet, let declaration):
                    guard includesSelectionSet else { continue }
                    try validateSelectionSet(
                        fragment.resolvedSelectionSet,
                        conformances: declaration.conformances,
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
        let variableDefinitions = operation.operation.ast.variableDefinitions
        if !variableDefinitions.isEmpty {
            operationTypes[.variables] = NestedTypeSource(
                description: "Generated operation variables type: Variables",
                responseKey: nil
            )
        }
        try validateNestedTypeNames(
            operationTypes,
            against: configuration.output.documents.operations.responseData.conformances,
            in: document.url
        )
        if !variableDefinitions.isEmpty {
            try validateNestedTypeNames(
                operationTypes,
                against: configuration.output.documents.operations.variables.conformances,
                in: document.url
            )
            for variableDefinition in variableDefinitions {
                try validateReferences(
                    typeReferences(in: variableDefinition.type.typeName),
                    shadowedBy: operationTypes,
                    source: "Operation variable: \(variableDefinition.variable.name.value)",
                    documentURL: document.url
                )
            }
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
        let includesDecodable = conformances.contains { conformance in
            SwiftConformanceName(source: conformance).includesDecodable
        }
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
        try validateModuleQualifiers(
            in: localTypes,
            conformances: conformances,
            documentURL: documentURL
        )
        let typesVisibleInScope = visibleNestedTypes.merging(localTypes) { _, local in local }
        try validateNestedTypeNames(typesVisibleInScope, against: conformances, in: documentURL)
        try validateStandardLibraryConformances(
            conformances,
            shadowedBy: typesVisibleInScope,
            documentURL: documentURL
        )
        if includesDecodable, typePlan.hasFragments {
            try validateQualifiableReference(
                .init(.swift, "Decoder"),
                shadowedBy: typesVisibleInScope,
                source: "Generated Decodable initializer",
                documentURL: documentURL
            )
            if !typePlan.fields.isEmpty {
                try validateQualifiableReference(
                    .init(.swift, "CodingKey"),
                    shadowedBy: typesVisibleInScope,
                    source: "Generated CodingKeys conformance",
                    documentURL: documentURL
                )
            }
        }

        for (responseKey, selection) in selectionSet {
            switch selection {
            case .field(let field, _):
                try validateReferences(
                    typeReferences(in: field.type),
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

    private func validateNestedTypeNames(
        _ nestedTypes: [SwiftTypeIdentifier: NestedTypeSource],
        against conformances: [String],
        in documentURL: URL
    ) throws {
        let reservedTypeNames = Set(lookupTypeNames(in: conformances))
        for (typeName, source) in nestedTypes where reservedTypeNames.contains(typeName) {
            try validateReservedTypeName(
                typeName: typeName,
                reservedTypeNames: reservedTypeNames,
                source: source.description,
                resolution: source.responseKey == nil ?
                    "Change the conflicting conformance in codegen configuration." :
                    "Use a GraphQL field alias that produces a distinct Swift type name.",
                documentURL: documentURL
            )
        }
    }

    private func validateModuleQualifiers(
        in declarations: [SwiftTypeIdentifier: NestedTypeSource],
        conformances: [String],
        documentURL: URL
    ) throws {
        let conformanceModules = conformances.compactMap { conformance in
            SwiftConformanceName(source: conformance).moduleQualifier
        }
        let moduleQualifiers = Set(conformanceModules)
        for (typeName, source) in declarations where moduleQualifiers.contains(typeName) {
            try validateReservedTypeName(
                typeName: typeName,
                reservedTypeNames: moduleQualifiers,
                source: source.description,
                resolution: "Use a GraphQL field alias that does not shadow a generated module reference.",
                documentURL: documentURL
            )
        }
    }

    private func validateReferences(
        _ references: Set<SwiftTypeIdentifier>,
        shadowedBy declarations: [SwiftTypeIdentifier: NestedTypeSource],
        source: String,
        documentURL: URL?
    ) throws {
        for reference in references {
            guard let conflictingSource = declarations[reference] else { continue }
            if let reference = SwiftTypeReference(nativeScalarName: reference.unescaped) {
                try validateQualifiableReference(
                    reference,
                    shadowedBy: declarations,
                    source: source,
                    documentURL: documentURL
                )
                continue
            }
            throw generatedReferenceConflictError(
                reference: reference,
                source: source,
                conflictingSource: conflictingSource,
                documentURL: documentURL
            )
        }
    }

    private func validateStandardLibraryConformances(
        _ conformances: [String],
        shadowedBy declarations: [SwiftTypeIdentifier: NestedTypeSource],
        documentURL: URL
    ) throws {
        for conformance in conformances {
            guard let reference = SwiftConformanceName(
                source: conformance
            ).standardLibraryReference else {
                continue
            }
            try validateQualifiableReference(
                reference,
                shadowedBy: declarations,
                source: "Generated conformance: \(conformance)",
                documentURL: documentURL
            )
        }
    }

    private func validateQualifiableReference(
        _ reference: SwiftTypeReference,
        shadowedBy declarations: [SwiftTypeIdentifier: NestedTypeSource],
        source: String,
        documentURL: URL?
    ) throws {
        let referenceIsShadowed = topLevelTypeNames.contains(reference.name) ||
            declarations[reference.name] != nil
        guard referenceIsShadowed,
              let moduleSource = declarations[
                  SwiftTypeIdentifier(swiftName: reference.module.rawValue)
              ] else {
            return
        }
        throw generatedReferenceConflictError(
            reference: SwiftTypeIdentifier(swiftName: reference.module.rawValue),
            source: source,
            conflictingSource: moduleSource,
            documentURL: documentURL
        )
    }

    private func lookupTypeNames(in conformances: [String]) -> [SwiftTypeIdentifier] {
        conformances.compactMap { conformance in
            let conformance = SwiftConformanceName(source: conformance)
            guard conformance.standardLibraryReference == nil else { return nil }
            return conformance.lookupTypeName
        }
    }

    private func typeReferences(in type: ResolvedFieldType) -> Set<SwiftTypeIdentifier> {
        switch type {
        case .scalar(let typeName, let isEnum):
            var references = Set([lookupTypeName(in: typeName)])
            if isEnum {
                references.insert(SwiftTypeIdentifier(swiftName: "GraphQLEnum"))
            }
            return references
        case .map:
            return []
        case .list(let innerType), .optional(let innerType):
            return typeReferences(in: innerType)
        }
    }

    private func typeReferences(in type: SourceTypeName) -> Set<SwiftTypeIdentifier> {
        var references: Set<SwiftTypeIdentifier> = []
        _ = type.formatted { name in
            references.insert(lookupTypeName(in: name))
            return name
        }
        return references
    }

    private func lookupTypeName(in source: String) -> SwiftTypeIdentifier {
        let name = source.split(separator: ".", maxSplits: 1).first.map(String.init) ?? source
        return SwiftTypeIdentifier(swiftName: name)
    }

    private func validateReservedTypeName(
        typeName: SwiftTypeIdentifier,
        reservedTypeNames: Set<SwiftTypeIdentifier>,
        source: String,
        resolution: String,
        documentURL: URL?
    ) throws {
        guard reservedTypeNames.contains(typeName) else { return }
        throw Codegen.Error(description: """
        A generated Swift type uses a name reserved by generated code.
        \(source)
        Swift type name: \(typeName.source)\(documentURL.map { "\nFile: \($0)" } ?? "")

        \(resolution)
        """)
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
        documentURL: URL?
    ) -> Codegen.Error {
        Codegen.Error(description: """
        A generated nested Swift type shadows a type referenced by generated code.
        \(conflictingSource.description)
        Reference source: \(source)
        Swift type name: \(reference.source)\(documentURL.map { "\nFile: \($0)" } ?? "")

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
}
