struct HTTPGenerationPlan {
    enum Mode {
        case getWithAutomaticPersistence
        case getWithRegisteredPersistence
        case getWithoutPersistence
        case postWithAutomaticPersistence
        case postWithRegisteredPersistence
        case postWithoutPersistence
    }

    enum Persistence {
        case automatic
        case registered
        case none
    }

    let enablesGETQueries: Bool
    let includesSubscriptions: Bool
    let persistence: Persistence

    var mode: Mode {
        switch (enablesGETQueries, persistence) {
        case (true, .automatic): .getWithAutomaticPersistence
        case (true, .registered): .getWithRegisteredPersistence
        case (true, .none): .getWithoutPersistence
        case (false, .automatic): .postWithAutomaticPersistence
        case (false, .registered): .postWithRegisteredPersistence
        case (false, .none): .postWithoutPersistence
        }
    }

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
