import SwiftUI

struct ContentView: View {
    @State private var viewModel = StarWarsViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section {
                    Text("Run each generated operation against the public Cloudflare Worker.")
                }

                Section("Hero query") {
                    Picker("Episode", selection: $viewModel.heroEpisode) {
                        episodeOptions
                    }
                    Button("Fetch hero") {
                        Task { await viewModel.fetchHero() }
                    }
                    .disabled(viewModel.heroStatus.isRunning)
                    operationResult(viewModel.heroStatus)
                }

                Section("Set favorite episode mutation") {
                    Picker("Episode", selection: $viewModel.favoriteEpisode) {
                        episodeOptions
                    }
                    Button("Set favorite episode") {
                        Task { await viewModel.setFavoriteEpisode() }
                    }
                    .disabled(viewModel.mutationStatus.isRunning)
                    operationResult(viewModel.mutationStatus)
                }

                Section("Favorite episode subscription") {
                    Text("The example server emits one episode and then completes the stream.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Start subscription") {
                        Task { await viewModel.subscribeToFavoriteEpisode() }
                    }
                    .disabled(viewModel.subscriptionStatus.isRunning)
                    operationResult(viewModel.subscriptionStatus)
                }
            }
            .navigationTitle("Star Wars GraphQL")
        }
    }

    private var episodeOptions: some View {
        ForEach(EpisodeChoice.allCases) { episode in
            Text(episode.title).tag(episode)
        }
    }

    @ViewBuilder
    private func operationResult(_ status: OperationStatus) -> some View {
        switch status {
        case .idle:
            EmptyView()
        case .running:
            HStack {
                ProgressView()
                Text("Loading…")
                    .foregroundStyle(.secondary)
            }
        case .succeeded(let message):
            Text(message)
                .font(.callout.monospaced())
                .textSelection(.enabled)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    ContentView()
}
