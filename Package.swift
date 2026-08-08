// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "swift-graphql-codegen",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .library(name: "GraphQLCodegen", targets: ["GraphQLCodegen"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections", from: "1.6.0"),
    ],
    targets: [
        .target(
            name: "GraphQLCodegen",
            dependencies: [
                .product(name: "OrderedCollections", package: "swift-collections"),
            ],
            resources: [
                .copy("Resources/graphql.bundle.js"),
            ]
        ),
        .target(
            name: "StarwarsExample",
            path: "Examples/StarwarsExample/Sources/StarwarsExample",
            exclude: [
                "Codegen.swift",
                "Operations/FavoriteEpisodeChangedSubscription.graphql",
                "Operations/HeroQuery.graphql",
                "Operations/SetFavoriteEpisodeMutation.graphql",
                "schema.sdl",
            ]
        ),
        .testTarget(
            name: "GraphQLCodegenTests",
            dependencies: [
                .target(name: "GraphQLCodegen"),
                .target(name: "StarwarsExample"),
            ],
            exclude: [
                "Fixtures/Defaults/Definitions",
                "Fixtures/OneOf/Definitions",
                "GraphQLCodegen.xctestplan",
            ]
        ),
    ]
)
