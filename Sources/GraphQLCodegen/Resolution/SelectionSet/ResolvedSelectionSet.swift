import OrderedCollections

typealias ResolvedSelectionSet = OrderedDictionary<String, ResolvedSelection>

/// Describes when a named fragment is fulfilled by the response and operation variables.
indirect enum FragmentFulfillmentCondition: Equatable, Sendable {
    case literal(Bool)
    case typename(String)
    case ancestorTypename(String, levelsUp: Int)
    case include(String)
    case skip(String)
    case and([FragmentFulfillmentCondition])
    case or([FragmentFulfillmentCondition])

    static func all(_ conditions: [FragmentFulfillmentCondition]) -> FragmentFulfillmentCondition? {
        let conditions = conditions.flatMap { condition in
            if case .and(let nested) = condition { return nested }
            return [condition]
        }
        if conditions.contains(.literal(false)) { return .literal(false) }
        let effectiveConditions = conditions.filter { $0 != .literal(true) }
        switch effectiveConditions.count {
        case 0: return nil
        case 1: return effectiveConditions[0]
        default: return .and(effectiveConditions)
        }
    }

    static func any(_ conditions: [FragmentFulfillmentCondition]) -> FragmentFulfillmentCondition? {
        let conditions = conditions.flatMap { condition in
            if case .or(let nested) = condition { return nested }
            return [condition]
        }
        if conditions.contains(.literal(true)) { return nil }
        let effectiveConditions = conditions.filter { $0 != .literal(false) }
        switch effectiveConditions.count {
        case 0: return .literal(false)
        case 1: return effectiveConditions[0]
        default: return .or(effectiveConditions)
        }
    }

    var requiresCurrentTypename: Bool {
        switch self {
        case .typename: true
        case .literal, .ancestorTypename, .include, .skip: false
        case .and(let conditions), .or(let conditions): conditions.contains { $0.requiresCurrentTypename }
        }
    }

    var dependsOnDirectiveVariables: Bool {
        switch self {
        case .include, .skip: true
        case .literal, .typename, .ancestorTypename: false
        case .and(let conditions), .or(let conditions): conditions.contains { $0.dependsOnDirectiveVariables }
        }
    }

    var directiveVariableNames: Set<String> {
        switch self {
        case .include(let name), .skip(let name): [name]
        case .literal, .typename, .ancestorTypename: []
        case .and(let conditions), .or(let conditions):
            conditions.reduce(into: Set<String>()) { names, condition in
                names.formUnion(condition.directiveVariableNames)
            }
        }
    }

    func dependsOnAncestorTypename(levelsUp: Int? = nil) -> Bool {
        switch self {
        case .ancestorTypename(_, let conditionLevelsUp): levelsUp == nil || levelsUp == conditionLevelsUp
        case .literal, .typename, .include, .skip: false
        case .and(let conditions), .or(let conditions):
            conditions.contains { $0.dependsOnAncestorTypename(levelsUp: levelsUp) }
        }
    }
}

enum ResolvedSelection: Sendable {
    case fragmentSpread(String, condition: FragmentFulfillmentCondition?)
    case field(ResolvedField, conditional: Bool)

    private enum MergeError: Error {
        case incompatibleSelectionTypes(ResolvedSelection, ResolvedSelection)
    }

    func merging(with other: ResolvedSelection) throws -> ResolvedSelection {
        switch self {
        case .fragmentSpread(let name, let condition):
            switch other {
            case .fragmentSpread(_, let otherCondition):
                guard let condition, let otherCondition else {
                    return .fragmentSpread(name, condition: nil)
                }
                return .fragmentSpread(name, condition: FragmentFulfillmentCondition.any([condition, otherCondition]))
            case .field: throw MergeError.incompatibleSelectionTypes(self, other)
            }
        case .field(let field, let conditional):
            switch other {
            case .fragmentSpread: throw MergeError.incompatibleSelectionTypes(self, other)
            case .field(let otherField, let otherConditional):
                return try .field(field.merging(with: otherField), conditional: conditional && otherConditional)
            }
        }
    }
}
