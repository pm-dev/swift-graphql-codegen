import Foundation

struct ResolvedDocuments {
    let documents: [ResolvedDocument]
    let fragmentLookup: [String: ResolvedFragment]
    let fulfilledFragments: Set<String>
    let hasMutation: Bool
    let hasSubscription: Bool
    let indirectOneOfInputObjectFields: [String: Set<String>]
    let requiresIndirectNullable: Bool
    let usedTypes: Set<String>
}

struct ResolvedDocument {
    let document: Document
    let resolvedDefinitions: [ResolvedDefinition]
}

enum ResolvedDefinition {
    case operation(ResolvedOperation)
    case fragment(String)
}

struct ResolvedOperation {
    let operation: Document.Operation
    let resolvedSelectionSet: ResolvedSelectionSet
}

struct ResolvedFragment {
    let fragment: Document.Fragment
    let resolvedSelectionSet: ResolvedSelectionSet
}
