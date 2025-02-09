import OrderedCollections

struct ResolvedField {
    private enum MergeError: Error {
        case incompatibleFields(ResolvedField, ResolvedField)
    }

    let type: ResolvedFieldType
    let deprecation: Deprecation?
    let description: String?

    func merging(with other: ResolvedField) throws -> ResolvedField {
        guard deprecation == other.deprecation
        else {
            throw MergeError.incompatibleFields(self, other)
        }
        var descriptions = OrderedSet<String>()
        if let description { descriptions.append(description) }
        if let otherDescription = other.description { descriptions.append(otherDescription) }
        return try ResolvedField(
            type: type.merging(with: other.type),
            deprecation: deprecation,
            description: descriptions.joined(separator: "\n")
        )
    }

    func asOptional() -> ResolvedField {
        switch type {
        case .optional:
            self
        case .list, .map, .scalar:
            ResolvedField(
                type: .optional(innerType: type),
                deprecation: deprecation,
                description: description
            )
        }
    }

    func asNonOptional() -> ResolvedField {
        switch type {
        case .optional(let innerType):
            ResolvedField(
                type: innerType,
                deprecation: deprecation,
                description: description
            )
        case .list, .map, .scalar:
            self
        }
    }

    func sourceTypeName(
        responseKey: String,
        scalarConversion: (_ name: String, _ isEnum: Bool) -> String = { $1 ? "GraphQLEnum<\($0)>" : $0 }
    ) -> SourceTypeName {
        _sourceTypeName(
            type: type,
            responseKey: responseKey,
            scalarConversion: scalarConversion
        )
    }

    private func _sourceTypeName(
        type: ResolvedFieldType,
        responseKey: String,
        scalarConversion: (_ name: String, _ isEnum: Bool) -> String
    ) -> SourceTypeName {
        switch type {
        case .scalar(let name, let isEnum): .name(scalarConversion(name, isEnum))
        case .map: .name(responseKey.capitalizedFirst)
        case .list(let innerType):
            .list(
                _sourceTypeName(
                    type: innerType,
                    responseKey: responseKey,
                    scalarConversion: scalarConversion
                )
            )
        case .optional(let innerType):
            .optional(
                _sourceTypeName(
                    type: innerType,
                    responseKey: responseKey,
                    scalarConversion: scalarConversion
                )
            )
        }
    }
}
