// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Codegen",
    platforms: [
        .macOS(.v26),
    ],
    dependencies: [
        .package(path: "../../.."),
    ],
    targets: [
        .executableTarget(
            name: "Codegen",
            dependencies: [
                .product(name: "GraphQLCodegen", package: "swift-graphql-codegen"),
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ]
)
