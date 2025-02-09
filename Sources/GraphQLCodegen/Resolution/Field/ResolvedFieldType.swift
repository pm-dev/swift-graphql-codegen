indirect enum ResolvedFieldType: Sendable {
    case scalar(typeName: String, isEnum: Bool)
    case map(ResolvedSelectionSet)
    case list(innerType: ResolvedFieldType)
    case optional(innerType: ResolvedFieldType)

    private enum MergeError: Error {
        case incompatibleFieldTypes(ResolvedFieldType, ResolvedFieldType)
    }

    func merging(with other: ResolvedFieldType) throws -> ResolvedFieldType {
        switch (self, other) {
        case (.scalar(let name1, let isEnum1), .scalar(let name2, let isEnum2)):
            guard name1 == name2, isEnum1 == isEnum2 else {
                throw MergeError.incompatibleFieldTypes(self, other)
            }
            return self
        case (.map(let selectionSet1), .map(let selectionSet2)):
            return .map(try selectionSet1.merging(selectionSet2) { try $0.merging(with: $1) })
        case (.optional(let inner1), .optional(let inner2)):
            return try .optional(innerType: inner1.merging(with: inner2))
        case (.list(let inner1), .list(let inner2)):
            return try .list(innerType: inner1.merging(with: inner2))
        default: throw MergeError.incompatibleFieldTypes(self, other)
        }
    }

    func unwrappedMap() -> ResolvedSelectionSet? {
        switch self {
        case .scalar: nil
        case .map(let resolvedSelectionSet): resolvedSelectionSet
        case .list(let innerType): innerType.unwrappedMap()
        case .optional(let innerType): innerType.unwrappedMap()
        }
    }
}
