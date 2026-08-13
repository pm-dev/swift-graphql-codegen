<p align="center">
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-lightgrey.svg?maxAge=2592000" alt="MIT license">
  </a>
  <a href="https://github.com/apple/swift">
    <img src="https://img.shields.io/badge/Swift-6.3-orange.svg" alt="Swift 6.3 supported">
  </a>
  <a href="https://swift.org/package-manager/">
    <img src="https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square" alt="Swift Package Manager compatible">
  </a>
  <a href="#requirements">
    <img src="https://img.shields.io/badge/generator-macOS%2026%2B-333333.svg" alt="Generator host: macOS 26 or newer" />
  </a>
</p>

# Swift GraphQL Codegen

Swift GraphQL Codegen generates type-safe Swift models and optional networking helpers from GraphQL schemas and operation documents.

Supports the [September 2025 GraphQL specification](https://spec.graphql.org/September2025/), including `@oneOf` input objects,
executable-document descriptions, schema coordinates, deprecated input values, and modern schema introspection.

- Operation and response models built from Swift structs with stored properties
- GraphQL enums and `@oneOf` input objects represented as Swift enums
- Typed named fragments and conditional `@include` and `@skip` directives
- Native `Codable` generation and `Sendable` defaults
- No runtime package dependency in client applications

Given this GraphQL operation:

```graphql
query Hero($episode: Episode!) {
  hero(episode: $episode) {
    id
    name
  }
}
```

Codegen produces an operation type with nested variables and response models:

```swift
struct HeroQuery: GraphQLQuery {
    static let operationName: String? = "Hero"

    static let document = #"""
    query Hero($episode: Episode!) {
      hero(episode: $episode) {
        id
        name
      }
    }
    """#

    let variables: Variables
    let extensions: [String: AnyEncodable]?

    struct Variables: Encodable, Sendable {
        let episode: Episode
    }

    struct Data: Decodable, Sendable, Hashable {
        let hero: Hero

        struct Hero: Decodable, Sendable, Hashable {
            let id: ID
            let name: String
        }
    }
}
```

- Response models mirror the shape of the response JSON.
- Values decode directly into stored properties rather than a backing dictionary.
- Named fragments remain separate types so you can extend and reuse them across operations.
- Only schema types referenced by an operation are generated.

The [Star Wars example](StarwarsExample) demonstrates the generator. The
[generated Node query](Tests/Fixtures/Generated/Operations/NodeQuery.graphql.swift) shows a complete generated operation.

## Usage

Swift GraphQL Codegen supports three integration options:

1. **Swift API:** Configure and run `Codegen` directly. [Example](StarwarsExample/README.md#swift-api-client).
2. **SwiftPM build-tool plugin:** Generate Swift sources automatically during package builds. [Example](StarwarsExample/README.md#build-tool-plugin-client).
3. **Standalone CLI:** Generate Swift sources manually or from a script. [Example](StarwarsExample/README.md#standalone-cli-client).

### 1. Swift API

Add `GraphQLCodegen` as a dependency of an executable target:

```swift
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "MyCodegenCLI",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(name: "my-codegen-cli", targets: ["MyCodegenCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pm-dev/swift-graphql-codegen", from: "0.7.2"),
    ],
    targets: [
        .executableTarget(
            name: "MyCodegenCLI",
            dependencies: [
                .product(name: "GraphQLCodegen", package: "swift-graphql-codegen"),
            ]
        ),
    ]
)
```

Configure the executable with a schema, GraphQL operation directory, and generated output directory:

```swift
import Foundation
import GraphQLCodegen

@main
struct MyCodegenCLI {
    private static let sourceDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

    static func main() async throws {
        let generatedDirectory = sourceDirectory.appending(path: "Generated", directoryHint: .isDirectory)

        try await Codegen(
            .configuration(
                input: .input(
                    schemaSource: .SDLSchemaFile(
                        sourceDirectory.appending(path: "schema.sdl", directoryHint: .notDirectory)
                    ),
                    documentDirectories: [
                        sourceDirectory.appending(path: "Operations", directoryHint: .isDirectory),
                    ]
                ),
                output: .output(
                    schema: .schema(directory: generatedDirectory),
                    support: .support(directory: generatedDirectory)
                )
            )
        ).run()
    }
}
```

Run the generator from the package directory:

```bash
swift run my-codegen-cli
```

### 2. SwiftPM Build-Tool Plugin

Add `GraphQLCodegenPlugin` to the Swift package target containing your GraphQL operations:

```swift
.target(
    name: "MyAPI",
    plugins: [
        .plugin(
            name: "GraphQLCodegenPlugin",
            package: "swift-graphql-codegen"
        ),
    ]
)
```

Add `graphql-codegen.json` to the target's directory, such as `Sources/MyAPI/graphql-codegen.json`:

```json
{
  "input": {
    "schemaSource": "schema.graphqls",
    "documentDirectories": ["GraphQL"]
  },
  "output": {
    "schema": {},
    "support": {}
  }
}
```

Paths are relative to `graphql-codegen.json`. The schema must be a checked-in SDL or introspection JSON file because SwiftPM
build-tool plugins cannot access the network.

### 3. Standalone CLI

The `graphql-codegen` executable accepts the same `graphql-codegen.json` configuration shown above:

```bash
swift run graphql-codegen --file-configuration /path/to/graphql-codegen.json --output-directory /path/to/generated
```

Instead of using `--output-directory`, you can configure separate output locations for schema, support, and operation files.
The standalone CLI also supports remote introspection endpoints and custom request headers.

## Configuration

[Configuration](Sources/GraphQLCodegen/Configuration/Configuration.swift) supports:

- Schema sources: SDL files, introspection JSON files, or remote introspection endpoints with custom request headers.
- GraphQL document directories and whether to include or exclude deprecated schema members.
- Separate output locations for generated schema types, operations and fragments, and shared support code.
- Generated file indentation, headers, imported modules, and access levels.
- Custom scalar mappings, including imported modules and optional module-qualified type names.
- Enum protocol conformances and case conversion.
- Input object property mutability and protocol conformances.
- Operation document minification, extension and variable property mutability, and protocol conformances.
- Variable, response, and named fragment model property mutability and protocol conformances.
- Explicit memberwise initializers for generated document types.
- Optional `URLSession` networking, GET queries, and server-sent event (SSE) subscriptions.
- [Automatic persisted queries](https://the-guild.dev/graphql/yoga-server/docs/features/automatic-persisted-queries) or
  [registered operations](https://the-guild.dev/graphql/yoga-server/docs/features/persisted-operations), with optional support for
  unregistered operations.

## Contributing

Contributions, documentation improvements, bug reports, and feature requests are welcome through pull requests and GitHub issues.

## Requirements

- Swift 6.3
- macOS 26 or later to run the generator
- iOS 15, macOS 12, tvOS 15, watchOS 8, or visionOS 1 or later for generated HTTP support
- macOS 26, iOS 26, tvOS 26, watchOS 26, or visionOS 26 or later for generated subscription support
