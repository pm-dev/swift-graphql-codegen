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
        // Demonstrates running GraphQL code generation directly through the Swift API.
        // Uses the configuration in Sources/Codegen/Codegen.swift
        .executableTarget(
            name: "Codegen",
            dependencies: [
                .product(name: "GraphQLCodegen", package: "swift-graphql-codegen"),
            ],
        ),
        // Demonstrates running GraphQL code generation through the SwiftPM build-tool plugin.
        // Uses the configuration in Sources/GraphQL/graphql-codegen.json
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
