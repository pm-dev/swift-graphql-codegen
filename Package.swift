// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "swift-graphql-codegen",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .library(name: "GraphQLCodegen", targets: ["GraphQLCodegen"]),
        .executable(name: "graphql-codegen", targets: ["graphql-codegen"]),
        .plugin(name: "GraphQLCodegenPlugin", targets: ["GraphQLCodegenPlugin"]),
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
            ],
        ),
        .executableTarget(
            name: "graphql-codegen",
            dependencies: [
                .target(name: "GraphQLCodegen"),
            ]
        ),
        .plugin(
            name: "GraphQLCodegenPlugin",
            capability: .buildTool(),
            dependencies: [
                .target(name: "graphql-codegen"),
            ]
        ),
        .target(
            name: "Fixtures",
            path: "Tests/Fixtures/Generated",
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .target(
            name: "PluginFixtures",
            path: "Tests/Fixtures/Plugin",
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ],
            plugins: [
                .plugin(name: "GraphQLCodegenPlugin"),
            ]
        ),
        .testTarget(
            name: "GraphQLCodegenTests",
            dependencies: [
                .target(name: "GraphQLCodegen"),
                .target(name: "graphql-codegen"),
                .target(name: "Fixtures"),
                .target(name: "PluginFixtures"),
            ],
            path: "Tests/Tests",
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ]
)
