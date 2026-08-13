import Foundation
import GraphQL
import Observation

enum EpisodeChoice: String, CaseIterable, Identifiable {
    case newHope
    case empire
    case jedi

    var id: Self { self }

    var title: String {
        switch self {
        case .newHope: "A New Hope"
        case .empire: "The Empire Strikes Back"
        case .jedi: "Return of the Jedi"
        }
    }

    var graphQLEpisode: GraphQL.Episode {
        switch self {
        case .newHope: .newHope
        case .empire: .empire
        case .jedi: .jedi
        }
    }
}

enum OperationStatus {
    case idle
    case running
    case succeeded(String)
    case failed(String)

    var isRunning: Bool {
        if case .running = self {
            true
        } else {
            false
        }
    }
}

@MainActor
@Observable
final class StarWarsViewModel {
    var heroEpisode = EpisodeChoice.newHope
    var favoriteEpisode = EpisodeChoice.newHope

    private(set) var heroStatus = OperationStatus.idle
    private(set) var mutationStatus = OperationStatus.idle
    private(set) var subscriptionStatus = OperationStatus.idle

    private let endpoint = URL(
        string: "https://swift-graphql-codegen-starwars.starwars-graphql-server.workers.dev/graphql"
    )!

    func fetchHero() async {
        heroStatus = .running
        do {
            let request = try GraphQLRequest(
                query: HeroQuery(episode: heroEpisode.graphQLEpisode),
                endpoint: endpoint
            )
            let response = try await URLSession.shared.request(request)
            guard let hero = response.data?.hero else {
                heroStatus = .failed(message(for: response.errors))
                return
            }

            if let jedi = hero.__jedi {
                heroStatus = .succeeded(
                    "Name: \(jedi.__character.name)\n"
                        + "ID: \(jedi.__character.id)\n"
                        + "Type: \(hero.__typename)\n"
                        + "Lightsaber: \(jedi.lightSaberColor)"
                )
            } else if let droid = hero.__droid {
                heroStatus = .succeeded(
                    "Name: \(droid.__character.name)\n"
                        + "ID: \(droid.__character.id)\n"
                        + "Type: \(hero.__typename)\n"
                        + "Primary function: \(droid.primaryFunction ?? "Unknown")\n"
                        + "Operator: \(droid.operator ?? "Unknown")"
                )
            } else {
                heroStatus = .failed("The server returned an unsupported hero type: \(hero.__typename).")
            }
        } catch is CancellationError {
            heroStatus = .idle
        } catch {
            heroStatus = .failed(error.localizedDescription)
        }
    }

    func setFavoriteEpisode() async {
        mutationStatus = .running
        do {
            let request = try GraphQLRequest(
                operation: SetFavoriteEpisodeMutation(episode: favoriteEpisode.graphQLEpisode),
                endpoint: endpoint
            )
            let response = try await URLSession.shared.request(request)
            guard let episode = response.data?.setFavoriteEpisode else {
                mutationStatus = .failed(message(for: response.errors))
                return
            }
            mutationStatus = .succeeded("Server returned: \(title(for: episode))")
        } catch is CancellationError {
            mutationStatus = .idle
        } catch {
            mutationStatus = .failed(error.localizedDescription)
        }
    }

    func subscribeToFavoriteEpisode() async {
        subscriptionStatus = .running
        do {
            let request = try GraphQLRequest(
                subscription: FavoriteEpisodeChangedSubscription(),
                endpoint: endpoint
            )
            let stream = try await URLSession.shared.subscribe(request)
            var messages: [String] = []
            for try await response in stream {
                if let episode = response.data?.favoriteEpisodeChanged {
                    messages.append("Received: \(title(for: episode))")
                }
                messages.append(contentsOf: response.errors?.map(\.message) ?? [])
            }
            messages.append("Stream completed.")
            subscriptionStatus = .succeeded(messages.joined(separator: "\n"))
        } catch is CancellationError {
            subscriptionStatus = .idle
        } catch {
            subscriptionStatus = .failed(error.localizedDescription)
        }
    }

    private func message(for errors: [GraphQLError]?) -> String {
        guard let errors, !errors.isEmpty else {
            return "The server returned no data."
        }
        return errors.map(\.message).joined(separator: "\n")
    }

    private func title(for episode: GraphQLEnum<GraphQL.Episode>) -> String {
        switch episode {
        case .known(let episode):
            return EpisodeChoice.allCases.first { $0.graphQLEpisode.rawValue == episode.rawValue }?.title
                ?? episode.rawValue
        case .unknown(let rawValue):
            return rawValue
        }
    }
}
