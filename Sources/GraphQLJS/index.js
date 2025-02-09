const { parse, validate, buildClientSchema, buildASTSchema, graphqlSync } = require('graphql');

function parseGraphQL(query) {
  return JSON.stringify(parse(query));
}

function validateDocument(document, JSONSchemaString) {
    try {
        const schema = buildClientSchema(JSON.parse(JSONSchemaString));
        const ast = parse(document);
        return JSON.stringify(validate(schema, ast));
    } catch (error) {
        return JSON.stringify(error);
    }
}

function convertSDLSchema(SDLSchemaString, introspectionQueryString) {
    try {
        const ast = parse(SDLSchemaString);
        const schema = buildASTSchema(ast);
        const result = graphqlSync({ schema, source: introspectionQueryString });
        return JSON.stringify(result.data);
    } catch (error) {
        return JSON.stringify(error);
    }
}

module.exports = { parseGraphQL, validateDocument, convertSDLSchema };
