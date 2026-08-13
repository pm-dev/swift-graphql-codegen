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
    targets: [
        .target(name: "GraphQL"),
    ]
)
