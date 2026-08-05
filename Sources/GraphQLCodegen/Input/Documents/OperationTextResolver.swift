import OrderedCollections

struct OperationTextResolver {
    let fragmentLookup: [String: Document.Fragment]
    let operationAST: GraphQLAST.OperationDefinition
    let operationSourceText: Substring

    func expandSourceText(
        mapFragmentSpread: (Document.Fragment) -> Substring
    ) throws -> String {
        var text = """
        \(operationSourceText)
        """
        let fragmentSpreads = try fragmentSpreadsDeep().compactMap(mapFragmentSpread)
        if !fragmentSpreads.isEmpty {
            text.append("\n")
            text.append(fragmentSpreads.joined(separator: "\n"))
        }
        return text
    }

    private func fragmentSpreadsDeep() throws -> [Document.Fragment] {
        var result: [Document.Fragment] = []
        var visited: Set<String> = []
        var stack: [GraphQLAST.SelectionSet] = [operationAST.selectionSet]
        while let current = stack.popLast() {
            for selection in current.selections {
                switch selection {
                case .inlineFragment(let inlineFragment):
                    stack.append(inlineFragment.selectionSet)
                case .fragmentSpread(let fragmentSpread):
                    if !visited.contains(fragmentSpread.name.value) {
                        visited.insert(fragmentSpread.name.value)
                        guard let fragment = fragmentLookup[fragmentSpread.name.value] else {
                            throw Codegen.Error(description: """
                            Fragment spread '...\(fragmentSpread.name.value)' used in operation \
                            \(operationAST.name?.value ?? "")
                            but no definition was found for the fragment.
                            """)
                        }
                        result.append(fragment)
                        stack.append(fragment.ast.selectionSet)
                    }
                case .field(let field):
                    if let selectionSet = field.selectionSet {
                        stack.append(selectionSet)
                    }
                }
            }
        }
        return result
    }
}
