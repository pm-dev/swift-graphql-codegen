// swift-tools-version: 6.3
import PackageDescription

let warningsAsErrors: [SwiftSetting] = [
    .treatAllWarnings(as: .error),
]

let package = Package(
    name: "StarwarsExample",
    platforms: [
        .macOS(.v26),
    ],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "StarwarsExample",
            dependencies: [
                .product(name: "GraphQLCodegen", package: "swift-graphql-codegen"),
            ],
            exclude: [
                "Operations/FavoriteEpisodeChangedSubscription.graphql",
                "Operations/HeroQuery.graphql",
                "Operations/SetFavoriteEpisodeMutation.graphql",
                "schema.sdl",
            ],
            swiftSettings: warningsAsErrors
        ),
    ]
)
