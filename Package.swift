// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-graphql-codegen",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "GraphQLCodegen", targets: ["GraphQLCodegen"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "GraphQLCodegen",
            dependencies: [
                .product(name: "OrderedCollections", package: "swift-collections"),
                .target(name: "LetterCase"),
            ],
            resources: [
                .copy("Resources/graphql.bundle.js"),
            ]
        ),
        .target(
            // From https://github.com/rwbutler/LetterCase.
            // See Sources/LetterCase/LICENSE for the upstream license.
            name: "LetterCase",
            exclude: ["LICENSE"]
        ),
        .testTarget(
            name: "GraphQLCodegenTests",
            dependencies: [
                .target(name: "GraphQLCodegen")
            ],
            exclude: [
                "Integration/ExpectedOutput/",
                "GraphQLCodegen.xctestplan",
            ]
        ),
        .executableTarget(
            name: "StarwarsExample",
            dependencies: [
                .target(name: "GraphQLCodegen"),
            ],
            exclude: [
                "Operations/HeroQuery.graphql",
                "schema.sdl",
            ]
        ),
    ]
)
