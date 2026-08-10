// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "GraphQL",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(
            name: "GraphQL",
            targets: ["GraphQL"]
        ),
    ],
    targets: [
        .target(
            name: "GraphQL",
            path: ".",
            exclude: [
                "Operations/FavoriteEpisodeChangedSubscription.graphql",
                "Operations/HeroQuery.graphql",
                "Operations/SetFavoriteEpisodeMutation.graphql",
            ],
            sources: [
                "Operations",
                "Schema",
                "Support",
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ]
)
