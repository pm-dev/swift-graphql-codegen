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
            ],
        ),
        .target(
            name: "Fixtures",
            path: "Tests/Fixtures/Generated",
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "GraphQLCodegenTests",
            dependencies: [
                .target(name: "GraphQLCodegen"),
                .target(name: "Fixtures"),
            ],
            path: "Tests/Tests",
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ]
)
