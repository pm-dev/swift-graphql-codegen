<p align="center">
  <a href="https://raw.githubusercontent.com/apollographql/apollo-ios/main/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-lightgrey.svg?maxAge=2592000" alt="MIT license">
  </a>
  <a href="https://github.com/apple/swift">
    <img src="https://img.shields.io/badge/Swift-6.0-orange.svg" alt="Swift 6.0 supported">
  </a>
  <a href="https://swift.org/package-manager/">
    <img src="https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square" alt="Swift Package Manager compatible">
  </a>
  <a href="Platforms">
    <img src="https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-333333.svg" alt="Supported Platforms: iOS, macOS, tvOS, watchOS" />
  </a>
</p>

# Swift GraphQL Codegen

Everything you need and nothing you don't. Swift GraphQL Codegen is a lightweight Swift library for generating type-safe Swift code from your GraphQL schema and operations. This library’s goal is to provide simple and customizable generation of Swift types to mirror your GraphQL documents, with optional built-in networking helpers tailored to your specific usage.

- [x] All types are structs
- [x] Stored properties
- [x] Serialization using Encodable/Decodable
- [x] Automatic Hashable/Equatable conformance
- [x] Swift concurrency support via Sendable conformance
- [x] Persisted operations support
- [x] Optional URLSession support, including support for query operations using GET and subscriptions using server-sent events
- [x] Schema can come from SDL, JSON or an introspection endpoint
- [x] Control over public/internal access level
- [x] Control over mutable or immutable types
- [x] Only generates types for scalars, enums, and input objects that are used by operations
- [x] No dependency added to your app binary

---

## Table of Contents
1. [Getting Started](#getting-started)  
2. [Example](#example-output)  
3. [Motivation](#motivation)  
4. [Design](#design)  
5. [Contributing](#contributing)  
6. [License](#license)  

---

## Getting Started

Below is a simple example demonstrating how you might integrate this library into your GraphQL project.

### Step 1: Create an SPM executable.

In `Package.swift` create an executable target that depends on this library:

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MyCodegenCLI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "my-codegen-cli", targets: ["MyCodegenCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pm-dev/swift-graphql-codegen", from: "0.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "MyCodegenCLI",
            dependencies: [
                .product(name: "GraphQLCodegen", package: "swift-graphql-codegen")
            ]
        )
    ]
)
```

### Step 2: Implement your codegen executable

In your executable target, create a command that imports the `GraphQLCodegen` module. The library provides a `Configuration` type to specify how you’d like your code generated (e.g., file output paths, usage of let vs. var, etc.). Pass this to the `Codegen.run` function. Explore the `Configuration` type to see all available configuration options. Most options come with a recommended default.

```swift
import GraphQLCodegen

@main
struct MyCodegenCLI {
    static func main() async throws {
        try await Codegen(
            .configuration(
                input: .input(
                    // SDL and JSON files are also supported
                    schemaSource: .introspectionEndpoint(URL(string: "http://localhost:5173/api/graphql")!),
                    documentDirectories: [graphQLDocumentsDirectory]
                ),
                output: .output(
                    schema: .schema(
                        directory: graphQLSchemaOutputDirectory
                    ),
                    api: .api(
                        directory: graphQLAPIOutputDirectory
                    )
                )
            )
        ).run()
    }
}
```

### Step 3: Compile and run your executable CLI

```bash
swift run my-codegen-cli
```

Your CLI will parse the schema and operations, then produce Swift types in the locations specified by your Configuration.


## Example

Below is an illustration of what the generated code might look like for an example Star Wars schema. Explore this codegen yourself by pulling the repository and playing around with the the Starwars example yourself, located in Sources/StarwarsExample

Suppose you have the following GraphQL schema:

```graphqls
type Query {
  hero(episode: Episode): Character!
}

interface Character {
  id: ID!
  name: String!
}

type Jedi implements Character {
  id: ID!
  name: String!
  lightSaberColor: String!
}

type Droid implements Character {
  id: ID!
  name: String!
  primaryFunction: String
}

enum Episode {
  NEWHOPE
  EMPIRE
  JEDI
}
```

And an operation:

```graphql
query Hero($episode: Episode!) {
  hero(episode: $episode) {
    id
    name
    ...on Jedi {
      lightSaberColor
    }
    ...on Droid {
      primaryFunction
    }
  }
}
```

The output will look like:

```swift
struct HeroQuery: GraphQLQuery {

    static let operationName: String? = "Hero"

    static let document = """
    query Hero($episode: Episode!) {
      hero(episode: $episode) {
        id
        name
        ...on Jedi {
          lightSaberColor
        }
        ...on Droid {
          primaryFunction
        }
      }
    }
    """

    let variables: Variables

    let extensions: [String: AnyEncodable]?

    init(
        episode: Episode,
        extensions: [String: AnyEncodable]? = nil
    ) {
        self.variables = Variables(
            episode: episode
        )
        self.extensions = extensions
    }

    struct Variables: Encodable, Sendable {

        let episode: Episode
    }

    struct Data: Decodable, Hashable, Sendable {

        let hero: Hero

        struct Hero: Decodable, Hashable, Sendable {

            let id: ID

            let name: String

            let lightSaberColor: String?

            let primaryFunction: String?
        }
    }
}

enum Episode: String, Encodable, Sendable {
    case NEWHOPE
    case EMPIRE
    case JEDI
}
```

Key features you’ll notice in the generated code:

- Structs: We represent each operation and response type as a Swift struct.
- Native Codable: Encodable and Decodable conformance using Swift’s built-in protocols.
- Automatic Equatable and Hashable: For easy comparison and set/dictionary usage.
- Swift Concurrency: By default, generated types conform to Sendable.
- Configuration: You can specify whether to use `var` or `let` for property declarations (among other options). By default, `let` is used in operation response types and `var` is used in fragment types, but this is customizable.

Let's take a look at an example using fragments:

```graphql
query Hero($episode: Episode!) {
  hero(episode: $episode) {
    __typename
    ...jedi
    ...droid
  }
}

fragment jedi on Jedi {
  ...character
  lightSaberColor
}

fragment droid on Droid {
  ...character
  primaryFunction
}

fragment character on Character {
  id
  name
}
```

Would output:

```swift
struct HeroQuery: GraphQLQuery {

    static let operationName: String? = "Hero"

    static let document = """
    query Hero($episode: Episode!) {
      hero(episode: $episode) {
        __typename
        ...jedi
        ...droid
      }
    }
    \(Jedi.source)
    \(Droid.source)
    \(Character.source)
    """

    let variables: Variables

    let extensions: [String: AnyEncodable]?

    init(
        episode: Episode,
        extensions: [String: AnyEncodable]? = nil
    ) {
        self.variables = Variables(
            episode: episode
        )
        self.extensions = extensions
    }

    struct Variables: Encodable, Sendable {

        let episode: Episode
    }

    struct Data: Decodable, Sendable {

        let hero: Hero

        struct Hero: Decodable, Sendable {

            let __typename: String

            let __jedi: Jedi?

            let __droid: Droid?

            init(from decoder: Decoder) throws {
                enum CodingKeys: CodingKey {
                    case __typename
                }
                let container = try decoder.container(keyedBy: CodingKeys.self)
                __typename = try container.decode(String.self, forKey: .__typename)
                __jedi = __typename == "Jedi" ? try Jedi(from: decoder) : nil
                __droid = __typename == "Droid" ? try Droid(from: decoder) : nil
            }
        }
    }
}

struct Jedi: Decodable, Sendable, Hashable {

    static let source = """
    fragment jedi on Jedi {
      ...character
      lightSaberColor
    }
    """

    var __character: Character

    var lightSaberColor: String

    init(from decoder: Decoder) throws {
        enum CodingKeys: CodingKey {
            case lightSaberColor
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lightSaberColor = try container.decode(String.self, forKey: .lightSaberColor)
        __character = try Character(from: decoder)
    }
}

struct Droid: Decodable, Sendable, Hashable {

    static let source = """
    fragment droid on Droid {
      ...character
      primaryFunction
    }
    """

    var __character: Character

    var primaryFunction: String?

    init(from decoder: Decoder) throws {
        enum CodingKeys: CodingKey {
            case primaryFunction
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        primaryFunction = try container.decode(String?.self, forKey: .primaryFunction)
        __character = try Character(from: decoder)
    }
}

struct Character: Decodable, Sendable, Hashable {

    static let source = """
    fragment character on Character {
      id
      name
    }
    """

    var id: ID

    var name: String
}
```


## Design

This library focuses on simplicity and ease of use. The generated types use structs, stored properties, Swift’s compiler-generated Encodable/Decodable and Equatable/Hashable where possible to greatly reduce boilerplate. Operation response types mirror your documents, with fields ordered consistently with the GraphQL spec. No underlying types or reflection-based logic. You can also optionally generate networking helpers using URLRequest and URLSession whose API is generated taking into consideration your Configuration options, giving you fine-grained control over how you integrate network requests in your project.
This library leverages the reference implementation [graphql-js](https://github.com/graphql/graphql-js) to ensure correctness. By bridging to graphql-js via Apple’s JavaScriptCore framework, we can parse and validate GraphQL schema and documents precisely according to the specification. This means as the GraphQL spec evolves, we can easily stay up to date by updating to the newest reference implementation.

Key design points:

- Extendable: You can add custom scalar definitions and add protocol conformances or module imports if needed.
- Tailored Networking: The opt-in networking code is generated in the same pass, ensuring an API that is as simple as possible. For example, Persisted Operations and GET queries are supported, but if those configuration options are turned off, the generated Networking APIs will be absent these concepts.
- Parsing & Validation: We delegate to graphql-js to parse and validate your schema and `.graphql` documents.

Simplicity also means this package is small, which keeps SPM resolution times and compile times fast
- ~70 Swift files
- ~5k lines of code
- ~3 second clean build compile time (M1 laptop)
- 1 dependency (Apple's OrderedCollections package)

## Alternatives

Alternative Swift GraphQL client libraries exist. This project was created to solve specific issues and reduce complexity. It has optimized for different tradeoffs than the libraries below. Choosing the right library will depend on your specific use case.

[Apollo iOS](https://github.com/apollographql/apollo-ios)

- A feature-rich library that includes codegen, caching and advanced networking infrastructure.
- All functionality is compiled into in a single binary regardless of whether you use it or not.
- Relies on computed properties from a backing dictionary
    - This can complicate local mutations and make it difficult to use generated types in your domain model.
    - This can make mocking data difficult.
- Missing `Sendable` conformances.
- [Uses unsafe fragment resolution](https://github.com/apollographql/apollo-ios/issues/3516).

[swift-graphql](https://github.com/maticzav/swift-graphql)

- `swift-graphql` is does not provide codegen from .graphql documents. Instead, you build typesafe queries in code. [Why swift-graphql](https://swift-graphql.com/why)
- This makes it easy to compose selection sets, however, fragments already solve this.
- [Manual decoding](https://swift-graphql.com/querying#decoding-values).


## Contributing
Contributions, documentation improvements, bug reports, and feature requests are welcome! Feel free to submit pull requests or open issues in our GitHub repository. We appreciate community involvement, whether it’s clarifying docs, squashing bugs, or proposing new features.


## License
This project is released under the MIT License.

Thanks for choosing Swift GraphQL Codegen! We hope it helps you deliver type-safe and maintainable GraphQL clients in Swift. If you have any questions or run into issues, please open an issue.
