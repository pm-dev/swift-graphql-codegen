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
        case registered(allowsUnregisteredOperations: Bool)
        case none
    }

    let enablesGETQueries: Bool
    let includesSubscriptions: Bool
    let persistence: Persistence

    var allowsUnregisteredOperations: Bool {
        guard case .registered(let allowsUnregisteredOperations) = persistence else { return false }
        return allowsUnregisteredOperations
    }

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
        switch configuration.output.api.HTTPSupport?.persistedOperations {
        case .automatic: persistence = .automatic
        case .registered(_, let allowUnregisteredOperations):
            persistence = .registered(allowsUnregisteredOperations: allowUnregisteredOperations)
        case .none: persistence = .none
        }
        self.enablesGETQueries = enablesGETQueries
        self.includesSubscriptions = hasSubscription &&
            configuration.output.api.HTTPSupport?.subscriptionSupport == true
        self.persistence = persistence
    }
}
