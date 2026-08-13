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

For both `.definition` and `.directory(URL)` document output, Codegen removes obsolete files ending in `.graphql.swift` from the
corresponding document directories while preserving other files. Do not use that suffix for independently maintained files in
those directories.

Codegen writes all referenced scalar, enum, and input-object declarations to `Schema.swift` inside `Schema.directory`. Each run
replaces that file while preserving other files in the same directory. Configure the generated file's header and imports through
`Schema.header` and `Schema.importedModules`.

Codegen writes shared GraphQL infrastructure and optional HTTP networking support to `Support.swift` inside `Support.directory`.
Each run replaces that file while preserving other files in the same directory. Schema, support, and document output may share
the same directory.

Configure custom Swift scalar types with `Scalars.scalarMapping`; scalars without a mapping default to `String`. Each mapping can
specify a module imported by `Schema.swift` and can optionally prefix the mapped type with the module name.

## Persisted Operations

Configure registered persisted operations with `.httpSupport(persistedOperations: .registered())`. Registered HTTP requests send
the SHA-256 hash of each operation's generated document. Set `.registered(allowUnregisteredOperations: true)` to allow sending
the full document instead during development.

Generate the registered-operation manifest separately from Swift output:

```swift
let codegen = Codegen(configuration)
try await codegen.run()
try await codegen.generatePersistedOperationManifestFile(at: manifestURL)
```

The manifest API works regardless of the configured HTTP persistence strategy and preserves the document minification setting.
`Codegen.run()` never writes a manifest.

## Subscription Limits

The generated GraphQL subscription API accepts LF, CRLF, and CR line endings and independently bounds SSE lines, complete event
payloads, and decoded results waiting for the consumer. Configure these limits with `maximumLineByteCount`,
`maximumEventByteCount`, and `maximumBufferedResultCount` when subscribing.

## Using Codegen

Swift GraphQL Codegen supports three integration options:

1. **Swift API:** Import `GraphQLCodegen`, create a `Configuration` in Swift, and run `Codegen` directly.
   [Swift API client example](StarwarsExample/README.md#swift-api-client).
2. **SwiftPM build-tool plugin and JSON configuration:** Attach `GraphQLCodegenPlugin` to a Swift package target and configure it
   with `graphql-codegen.json`. [Build-tool plugin client example](StarwarsExample/README.md#build-tool-plugin-client).
3. **Standalone CLI and JSON configuration:** Run the `graphql-codegen` executable with `--file-configuration` and a JSON file.
   [Standalone CLI client example](StarwarsExample/README.md#standalone-cli-client).

### 1. Swift API

Create a Swift package executable that configures and runs code generation directly through the `GraphQLCodegen` Swift API.

#### Add the Package

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

#### Configure Code Generation

The following executable reads `schema.sdl` and GraphQL operations from an `Operations` directory next to the source file, then
writes generated schema and support files to `Generated`:

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

JSON schema files and introspection endpoints are also supported through `Configuration.Input.SchemaSource`. JSON schema files
can contain either the introspection query's `data` object (`{"__schema": ...}`) or the complete GraphQL response
(`{"data": {"__schema": ...}}`).

#### Run the Generator

From the package directory, run:

```bash
swift run my-codegen-cli
```

### 2. SwiftPM Build-Tool Plugin and JSON Configuration

Use `GraphQLCodegenPlugin` to generate Swift sources automatically when SwiftPM builds a target. Add the plugin to each source
target that owns GraphQL operations:

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

Place `graphql-codegen.json` in that target's directory, such as `Sources/MyAPI/graphql-codegen.json`. Every file or directory URL
in the JSON must be relative to the directory containing `graphql-codegen.json`. The `output.schema` and `output.support` objects
are required, but their contents may be empty:

```json
{
  "input": {
    "schemaSource": "schema.graphqls",
    "documentDirectories": ["GraphQL"],
    "deprecationPolicy": "include"
  },
  "output": {
    "schema": {
      "scalars": {
        "scalarMapping": {
          "DateTime": {
            "typeName": "Date",
            "module": {
              "name": "Foundation",
              "prefix": true
            }
          }
        }
      },
      "accessLevel": "public"
    },
    "documents": {
      "accessLevel": "public"
    },
    "support": {
      "accessLevel": "public",
      "httpSupport": {
        "persistedOperations": {
          "strategy": "registered",
          "allowUnregisteredOperations": true
        },
        "subscriptionSupport": true
      }
    }
  }
}
```

The plugin declares one `Schema.swift` file, one `Support.swift` file, and one `.graphql.swift` file for each GraphQL document.
Generated files are written directly inside the SwiftPM work directory, with document output preserving each document's path
relative to its configured input directory. GraphQL document filenames must be unique within the target.
Plugin configurations must not set `output.schema.directory`,
`output.documents.directory`, or `output.support.directory`. The plugin never modifies `Sources` or executes the generator while
declaring its build command. SwiftPM can skip code generation when no declared input has changed.

Generated schema, document, and support access levels each default to `internal`. Set them to `public` when exposing generated types
from a package library. Set `output.support.httpSupport.enabled` to `false` to omit generated HTTP networking support. Subscription
support is disabled by default; enable it with `output.support.httpSupport.subscriptionSupport`. Set
`output.support.httpSupport.enableGETQueries` to `true` to enable GET requests. Each output category includes a generated-file
header by default; set its `includeHeader` option to `false` to omit that header.

`output.support.httpSupport.persistedOperations.strategy` accepts `"automatic"`, `"registered"`, or `"disabled"`. Automatic
persisted queries are enabled by default; use `"disabled"` to send complete GraphQL documents. Registered operations send their
document hash. Generate a manifest separately by calling
`Codegen.generatePersistedOperationManifestFile(at:)`.
Set `output.support.httpSupport.persistedOperations.allowUnregisteredOperations` to `true` to choose between registered hashes
and full operation documents at runtime, which allows unregistered operations during development.

The schema must be a checked-in SDL or introspection JSON file. Remote introspection is unsupported because SwiftPM build-tool
plugins run without network access. The plugin recursively declares every `.graphql` document in the configured directories,
along with the original configuration and schema, as build-command inputs. It passes the original JSON configuration and its
SwiftPM work directory directly to the executable.

### 3. Standalone CLI and JSON Configuration

Use the `graphql-codegen` executable to run code generation manually or from a script. It accepts the same JSON configuration
options as the build-tool plugin without the plugin's output-directory or remote-introspection restrictions.

Create a `graphql-codegen.json` file:

```json
{
  "input": {
    "schemaSource": "schema.graphqls",
    "documentDirectories": ["GraphQL"]
  },
  "output": {
    "schema": {
      "directory": "Generated"
    },
    "documents": {
      "directory": "Generated"
    },
    "support": {
      "directory": "Generated"
    }
  }
}
```

Pass that JSON file to the executable:

```bash
swift run graphql-codegen --file-configuration /path/to/graphql-codegen.json
```

Standalone configurations must provide `output.schema.directory` and `output.support.directory`. Set
`output.documents.directory` to place generated documents in one output directory, or omit it to generate documents beside their
GraphQL definitions. All file and directory URLs in the JSON must be relative to the directory containing `graphql-codegen.json`.
Remote introspection endpoints are not filesystem URLs and may use absolute HTTP or HTTPS URLs; set `input.schemaSource` to the
endpoint and optionally supply `input.schemaHeaders`.

Use `--output-directory` to place schema, support, and document files in one directory instead of using the output directories
from the JSON configuration:

```bash
swift run graphql-codegen --file-configuration /path/to/graphql-codegen.json --output-directory /path/to/generated
```

When `--output-directory` is supplied, `output.schema.directory` and `output.support.directory` may be omitted.

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

The [Star Wars example](StarwarsExample) demonstrates the generator. The
[generated Node query](Tests/Fixtures/Generated/Operations/NodeQuery.graphql.swift) shows a complete generated operation.

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
