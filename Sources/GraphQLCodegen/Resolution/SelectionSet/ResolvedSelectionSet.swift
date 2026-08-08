import OrderedCollections

typealias ResolvedSelectionSet = OrderedDictionary<String, ResolvedSelection>

enum ResolvedSelection {
    case fragmentSpread(String, checkTypenames: Set<String>?)
    case field(ResolvedField, conditional: Bool)

    func merging(with other: ResolvedSelection) throws -> ResolvedSelection {
        switch self {
        case .fragmentSpread(let name, let checkTypenames):
            switch other {
            case .fragmentSpread(_, let otherCheckTypenames):
                guard let checkTypenames, let otherCheckTypenames else {
                    return .fragmentSpread(name, checkTypenames: nil)
                }
                return .fragmentSpread(name, checkTypenames: checkTypenames.union(otherCheckTypenames))
            case .field: throw MergeError.incompatibleSelectionTypes(self, other)
            }
        case .field(let field, let conditional):
            switch other {
            case .fragmentSpread: throw MergeError.incompatibleSelectionTypes(self, other)
            case .field(let otherField, let otherConditional):
                return .field(try field.merging(with: otherField), conditional: conditional && otherConditional)
            }
        }
    }

    private enum MergeError: Error {
        case incompatibleSelectionTypes(ResolvedSelection, ResolvedSelection)
    }
}
