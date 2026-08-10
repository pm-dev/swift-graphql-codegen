import { useAPQ } from "@graphql-yoga/plugin-apq";
import { usePersistedOperations } from "@graphql-yoga/plugin-persisted-operations";
import { createSchema, createYoga } from "graphql-yoga";
import { registeredOperations } from "./registered-operations.generated";
import typeDefs from "./schema.graphql";

type Episode = "EMPIRE" | "JEDI" | "NEW_HOPE";

type Character =
  | {
      id: string;
      kind: "Droid";
      name: string;
      operator: string | null;
      primaryFunction: string | null;
    }
  | {
      id: string;
      kind: "Jedi";
      lightSaberColor: string;
      name: string;
    };

const artoo: Character = {
  id: "2001",
  kind: "Droid",
  name: "R2-D2",
  operator: "Luke Skywalker",
  primaryFunction: "Astromech",
};

const luke: Character = {
  id: "1000",
  kind: "Jedi",
  lightSaberColor: "green",
  name: "Luke Skywalker",
};

const heroes: Readonly<Record<Episode, Character>> = {
  EMPIRE: luke,
  JEDI: luke,
  NEW_HOPE: artoo,
};

const schema = createSchema({
  typeDefs,
  resolvers: {
    Character: {
      __resolveType(character: Character) {
        return character.kind;
      },
    },
    Mutation: {
      setFavoriteEpisode(_source: unknown, { episode }: { episode: Episode }) {
        return episode;
      },
    },
    Query: {
      hero(_source: unknown, { episode }: { episode?: Episode }) {
        return heroes[episode ?? "NEW_HOPE"];
      },
    },
    Subscription: {
      favoriteEpisodeChanged: {
        async *subscribe() {
          yield { favoriteEpisodeChanged: "NEW_HOPE" satisfies Episode };
        },
      },
    },
  },
});

const cors = {
  origin: "*",
};

const graphql = createYoga({
  cors,
  graphqlEndpoint: "/graphql",
  graphiql: false,
  plugins: [
    useAPQ({
      responseConfig: {
        forceStatusCodeOk: true,
      },
    }),
  ],
  schema,
});

const registeredGraphql = createYoga({
  cors,
  graphqlEndpoint: "/graphql-registered",
  graphiql: false,
  plugins: [
    usePersistedOperations({
      getPersistedOperation(hash) {
        return registeredOperations[hash] ?? null;
      },
    }),
  ],
  schema,
});

const graphiql = createYoga({
  graphqlEndpoint: "/graphql",
  graphiql: {
    defaultQuery: /* GraphQL */ `
      query Hero {
        hero(episode: EMPIRE) {
          __typename
          ... on Jedi {
            id
            name
            lightSaberColor
          }
          ... on Droid {
            id
            name
            primaryFunction
            operator
          }
        }
      }
    `,
    endpoint: "/graphql",
    subscriptionsProtocol: "SSE",
  },
  schema,
});

function graphiqlResponse(request: Request): Promise<Response> | Response {
  const url = new URL(request.url);
  url.pathname = "/graphql";

  const headers = new Headers(request.headers);
  headers.set("accept", "text/html");

  return graphiql.fetch(new Request(url, { headers }));
}

export default {
  fetch(request: Request): Promise<Response> | Response {
    const { pathname } = new URL(request.url);
    switch (pathname) {
      case "/graphql":
        return graphql.fetch(request);
      case "/graphql-registered":
        return registeredGraphql.fetch(request);
      case "/graphiql":
        if (request.method === "GET") {
          return graphiqlResponse(request);
        }
        return new Response("Method Not Allowed", {
          headers: { allow: "GET" },
          status: 405,
        });
      default:
        return new Response("Not Found", { status: 404 });
    }
  },
} satisfies ExportedHandler<Env>;
