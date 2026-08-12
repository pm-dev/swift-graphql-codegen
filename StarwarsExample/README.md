# Star Wars Example

The Star Wars example includes three independent clients that demonstrate different ways to generate Swift GraphQL sources.
Each client contains its own `StarwarsExample.xcodeproj` and uses the shared GraphQL schema in `server/src/schema.graphql`.

## Swift API Client

`client-swift-api` generates GraphQL sources directly with the `GraphQLCodegen` Swift API. Its `Codegen` executable creates a
Swift `Configuration` in `client-swift-api/Packages/GraphQL/Sources/Codegen/Codegen.swift`.

Regenerate its checked-in sources from `client-swift-api/Packages/GraphQL`:

```sh
swift run Codegen
```

You can also run the `Codegen` scheme in `client-swift-api/StarwarsExample.xcodeproj`.

## Build-Tool Plugin Client

`client-build-plugin` generates GraphQL sources automatically with `GraphQLCodegenPlugin`. Its `GraphQL` package target reads
`client-build-plugin/Packages/GraphQL/Sources/GraphQL/graphql-codegen.json` and writes generated sources to SwiftPM's plugin
work directory.

Open `client-build-plugin/StarwarsExample.xcodeproj` and build the application. No generated Swift files are checked in.

## Standalone CLI Client

`client-cli` generates GraphQL sources with the standalone `graphql-codegen` executable and the JSON configuration in
`client-cli/Packages/GraphQL/graphql-codegen.json`.

Regenerate its checked-in sources from `client-cli/Packages/GraphQL`:

```sh
./run-codegen
```

You can also run the `graphql-codegen` scheme in `client-cli/StarwarsExample.xcodeproj`.
