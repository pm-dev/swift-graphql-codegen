extension Configuration {
    func operationConformances(for operationType: GraphQLAST.OperationType) -> [String] {
        var conformances = output.documents.operations.conformances
        guard output.api.HTTPSupport != nil else { return conformances }
        switch operationType {
        case .query: conformances.append("GraphQLQuery")
        case .mutation: conformances.append("GraphQLMutation")
        case .subscription: conformances.append("GraphQLSubscription")
        }
        return conformances
    }
}
