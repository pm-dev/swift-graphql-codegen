# Star Wars GraphQL server

A static GraphQL API for the Swift Star Wars example, deployed as a Cloudflare Worker.

## Endpoints

- `/graphql` accepts arbitrary GraphQL operations and supports automatic persisted queries (APQ).
- `/graphql-registered` accepts only the operations checked into
  `../../Examples/StarwarsExample/Sources/StarwarsExample/Operations`.
- `/graphiql` opens GraphiQL against `/graphql`.

The mutation returns its input without persisting it. The subscription emits `NEW_HOPE` once and then completes.

## Development

```sh
npm install
npm run dev
```

The registered-operation allowlist is generated from the client operations before development, checks, and deployment. Regenerate it directly after changing an operation with:

```sh
npm run generate
```

Validate the TypeScript and Worker bundle with:

```sh
npm run check
```

## Deployment

Authenticate Wrangler with a Cloudflare account, then deploy to the public `workers.dev` hostname:

```sh
npm run deploy
```
