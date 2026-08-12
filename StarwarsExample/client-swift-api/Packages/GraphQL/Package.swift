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
        .executable(name: "Codegen", targets: ["Codegen"])
    ],
    dependencies: [
        .package(name: "swift-graphql-codegen", path: "../../../.."),
    ],
    targets: [
        .executableTarget(
            name: "Codegen",
            dependencies: [
                .product(name: "GraphQLCodegen", package: "swift-graphql-codegen"),
            ],
        ),
        .target(name: "GraphQL"),
    ]
)
