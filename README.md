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
  <a href="#platform-support">
    <img src="https://img.shields.io/badge/generator-macOS%2026%2B-333333.svg" alt="Generator host: macOS 26 or newer" />
  </a>
</p>

# Swift GraphQL Codegen

Swift GraphQL Codegen generates type-safe Swift models from GraphQL schemas and operation documents. It emits concrete models
with stored properties and can optionally generate networking helpers tailored to the enabled features.

- Operation and response models built from Swift structs with stored properties
- GraphQL enums represented as Swift enums
- Native `Codable` generation, `Sendable` defaults, and configurable model conformances
- Automatic and registered persisted operations
- Optional `URLSession` support for POST requests, GET queries, and server-sent event subscriptions
- SDL, JSON, and introspection schema inputs
- Configurable access levels and property mutability
- Schema types generated only when referenced by an operation
- No runtime package dependency added to the client application

Automatic persisted-operation fallback is supported for queries and mutations. Registered persisted operations are supported for
subscriptions, but automatic fallback is not.

## Platform Support

The code generator runs on macOS 26 or newer because it uses JavaScriptCore to execute the bundled GraphQL reference
implementation. Generated source deployment requirements depend on the enabled APIs. Subscription support requires version 26 or
newer of macOS, iOS, tvOS, watchOS, or visionOS.

## GraphQL Compatibility

Swift GraphQL Codegen targets the [September 2025 edition of the GraphQL specification](https://spec.graphql.org/September2025/).
Schemas and introspection endpoints must conform to that edition. Earlier introspection schemas are not supported; in particular,
an introspection endpoint must expose `__Type.isOneOf`.

## Output Directory Ownership

When document output is configured as `.directory(URL)`, Codegen assumes exclusive ownership of that directory and may remove all
of its existing contents before writing the current generated output. Do not store unrelated or independently maintained files in
that directory. With `.definition` output, Codegen instead removes obsolete files ending in `.graphql.swift` from the configured
document directories, so do not use that suffix for independently maintained files there.

Codegen assumes exclusive ownership of the configured schema output directories. Each run may remove and recreate the scalar,
enum, and input-object directories, including files that are not part of the current generated output. Do not store unrelated or
independently maintained files in these directories.

When a schema category's `directoryName` is `nil`, that category writes directly into `Schema.directory`, and Codegen treats the
schema root itself as an owned output directory. Customized scalar files are preserved while their scalar remains part of the
generated output; if the scalar is no longer used by an operation, its file may be removed on the next run.

## Subscription Limits

The generated GraphQL subscription API accepts LF, CRLF, and CR line endings and independently bounds SSE lines, complete event
payloads, and decoded results waiting for the consumer. Configure these limits with `maximumLineByteCount`,
`maximumEventByteCount`, and `maximumBufferedResultCount` when subscribing.

## Getting Started

Create a Swift package executable that runs code generation separately from your client application.

### 1. Add the Package

In `Package.swift`, add an executable target that depends on `GraphQLCodegen`:

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

### 2. Configure Code Generation

The following executable reads `schema.sdl` and GraphQL operations from an `Operations` directory next to the source file, then
writes generated schema and API files to `Generated`:

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
                    schemaSource: .file(.SDL(
                        sourceDirectory.appending(path: "schema.sdl", directoryHint: .notDirectory)
                    )),
                    documentDirectories: [
                        sourceDirectory.appending(path: "Operations", directoryHint: .isDirectory),
                    ]
                ),
                output: .output(
                    schema: .schema(
                        directory: generatedDirectory.appending(path: "SchemaTypes", directoryHint: .isDirectory)
                    ),
                    api: .api(
                        directory: generatedDirectory.appending(path: "API", directoryHint: .isDirectory)
                    )
                )
            )
        ).run()
    }
}
```

JSON schema files and introspection endpoints are also supported through `Configuration.Input.SchemaSource`.

### 3. Run the Generator

From the package directory, run:

```bash
swift run my-codegen-cli
```

## SwiftPM Build-Tool Plugin

Add `GraphQLCodegenPlugin` to each source target that owns GraphQL operations:

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

Place `graphql-codegen.json` in that target's directory, such as `Sources/MyAPI/graphql-codegen.json`. All paths are relative to
the configuration file:

```json
{
  "schema": {
    "path": "schema.graphqls",
    "importedModules": ["Foundation"],
    "scalarMappings": {
      "DateTime": "Foundation.Date"
    }
  },
  "documentDirectories": ["GraphQL"],
  "deprecationPolicy": "include",
  "output": {
    "schema": { "accessLevel": "public" },
    "documents": { "accessLevel": "public" },
    "api": {
      "accessLevel": "public",
      "subscriptionSupport": true
    }
  },
  "validation": true
}
```

Generated schema, document, and API access levels each default to `internal`. Set them to `public` when exposing generated types
from a package library. Subscription support is disabled by default and can be enabled with `output.api.subscriptionSupport`.

The schema must be a checked-in SDL or introspection JSON file. A remote introspection endpoint is intentionally unsupported because
SwiftPM build-tool plugins run without network access. The plugin recursively declares every `.graphql` document in the configured
directories, along with the configuration and schema, as build-command inputs.

Generated sources are written only to SwiftPM's plugin work directory; the plugin never modifies `Sources`. Its build command
declares exactly these outputs:

- `GraphQLAPI.generated.swift`
- `GraphQLDocuments.generated.swift`
- `GraphQLSchema.generated.swift`

Custom scalar mappings are regenerated into `GraphQLSchema.generated.swift`, with unmapped scalars defaulting to `String`.
Adjacent document output, custom filenames, and registered persisted-operation manifests are unsupported because each would prevent
the plugin from declaring the fixed output set. SwiftPM can therefore skip the build command when none of its declared inputs have
changed, instead of unconditionally running code generation as it would for a prebuild command.

The `GraphQLCodegen` library and manual executable workflow remain available. Standalone `Configuration` can opt into the same
`.generatedFiles` layout or retain flexible output locations, remote introspection, and editable generated scalar files.

## Generated Output

Given a GraphQL operation such as:

```graphql
query Hero($episode: Episode!) {
  hero(episode: $episode) {
    id
    name
  }
}
```

Codegen produces an operation type and nested response models. This abbreviated example shows the generated shape:

```swift
struct HeroQuery: GraphQLQuery {
    static let operationName: String? = "Hero"

    static let document = #"""
    query Hero($episode:Episode!){hero(episode:$episode){id name}}
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

The [Star Wars example](StarwarsExample) contains a runnable generator and its checked-in output, including the complete
[generated Hero query](StarwarsExample/client/Packages/GraphQL/Operations/HeroQuery.graphql.swift).

## Design

Generated response models use stored properties rather than a backing dictionary or reflection. Operation response types mirror
the selected fields, with response properties ordered consistently with the GraphQL specification. Custom scalars, protocol
conformances, imports, access levels, and mutability are configurable.

The generator uses a pinned version of [graphql-js](https://github.com/graphql/graphql-js) through JavaScriptCore to parse and
validate GraphQL schemas and documents.

### Generated Type Naming

The response key for a field is its alias when one is present, or its schema field name otherwise. When a selected field has a
selection set, Codegen names its nested response type by capitalizing that response key.

If two fields in the same selection set produce the same Swift type name, Codegen reports an error. For example, this valid
GraphQL selection would produce `struct Profile` for both fields:

```graphql
profile: Viewer { id }
Profile: Viewer { name }
```

Use an alias or fragment to resolve the conflict.

Before writing files, Codegen validates declarations in their actual Swift lexical scopes. This includes conflicts between
response keys, fragments, generated schema types, and fixed operation declarations or references such as `Data`, `Variables`, and
`CodingKey`.

Configured conformances are emitted verbatim and are not included in collision validation. Codegen neither qualifies generated
system type references nor validates collisions with Swift standard-library or Foundation types. Callers must avoid those
collisions with GraphQL aliases or fragment names and qualify configured types and conformances when necessary.

## Contributing

Contributions, documentation improvements, bug reports, and feature requests are welcome through pull requests and GitHub issues.

The generator ships a bundled copy of the GraphQL JavaScript reference implementation. After changing `Sources/GraphQLJS` or its
dependencies, run `./Scripts/update-graphql-bundle` and commit the updated
`Sources/GraphQLCodegen/Resources/graphql.bundle.js`. CI rebuilds the bundle from the frozen pnpm lockfile and verifies that the
committed resource is current.

## License

Swift GraphQL Codegen is available under the [MIT License](LICENSE).
