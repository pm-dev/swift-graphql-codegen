// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "GraphQL",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "GraphQL", targets: ["GraphQL"]),
    ],
    dependencies: [
        .package(name: "swift-graphql-codegen", path: "../../../.."),
    ],
    targets: [
        .target(
            name: "GraphQL",
            plugins: [
                .plugin(
                    name: "GraphQLCodegenPlugin",
                    package: "swift-graphql-codegen"
                ),
            ]
        ),
    ]
)
