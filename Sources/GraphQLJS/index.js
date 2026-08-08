const {
  parse,
  validate,
  buildClientSchema,
  buildASTSchema,
  graphqlSync,
  stripIgnoredCharacters,
} = require('graphql');

function execute(operation) {
  try {
    return { status: 'success', value: operation() };
  } catch (error) {
    return { status: 'invalidInput', message: String(error) };
  }
}

function parseGraphQL(query) {
  return execute(() => JSON.stringify(parse(query)));
}

function validateDocuments(documents, JSONSchemaString) {
  return execute(() => {
    const schema = buildClientSchema(JSON.parse(JSONSchemaString));
    return JSON.stringify(
      documents.map((document) => validate(schema, parse(document))),
    );
  });
}

function convertSDLSchema(SDLSchemaString, introspectionQueryString) {
  return execute(() => {
    const ast = parse(SDLSchemaString);
    const schema = buildASTSchema(ast);
    const result = graphqlSync({ schema, source: introspectionQueryString });
    if (result.errors?.length) {
      throw new Error(result.errors.map((error) => String(error)).join('\n'));
    }
    return JSON.stringify(result.data);
  });
}

function canonicalizeDocument(document) {
  return execute(() => stripIgnoredCharacters(document));
}

module.exports = { parseGraphQL, validateDocuments, convertSDLSchema, canonicalizeDocument };
