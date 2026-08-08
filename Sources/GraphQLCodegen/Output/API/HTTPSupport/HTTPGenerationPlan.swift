struct HTTPGenerationPlan {
    enum Persistence {
        case automatic
        case registered
        case none
    }

    let enablesGETQueries: Bool
    let includesSubscriptions: Bool
    let persistence: Persistence

    init(configuration: Configuration, hasSubscription: Bool) {
        let enablesGETQueries = configuration.output.api.HTTPSupport?.enableGETQueries == true
        let persistence: Persistence
        switch configuration.output.documents.operations.persistedOperations {
        case .automatic: persistence = .automatic
        case .registered: persistence = .registered
        case .none: persistence = .none
        }
        self.enablesGETQueries = enablesGETQueries
        self.includesSubscriptions = hasSubscription &&
            configuration.output.api.HTTPSupport?.subscriptionSupport == true
        self.persistence = persistence
    }
}
