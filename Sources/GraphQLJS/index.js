import {
  parse,
  validate,
  buildClientSchema,
  buildASTSchema,
  graphqlSync,
  stripIgnoredCharacters,
} from 'graphql';
import './abort-controller.js';

function execute(operation) {
  try {
    return { status: 'success', value: operation() };
  } catch (error) {
    return { status: 'invalidInput', message: String(error) };
  }
}

export function parseGraphQL(query) {
  return execute(() => JSON.stringify(parse(query)));
}

export function validateDocuments(documents, JSONSchemaString) {
  return execute(() => {
    const schema = buildClientSchema(JSON.parse(JSONSchemaString));
    return JSON.stringify(
      documents.map((document) => validate(schema, parse(document))),
    );
  });
}

export function convertSDLSchema(SDLSchemaString, introspectionQueryString) {
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

export function canonicalizeDocument(document) {
  return execute(() => {
    const ast = parse(document);
    const descriptionRanges = [];
    for (const definition of ast.definitions) {
      if (
        definition.kind !== 'OperationDefinition' &&
        definition.kind !== 'FragmentDefinition'
      ) {
        continue;
      }
      if (definition.description) {
        descriptionRanges.push(definition.description.loc);
      }
      for (const variableDefinition of definition.variableDefinitions ?? []) {
        if (variableDefinition.description) {
          descriptionRanges.push(variableDefinition.description.loc);
        }
      }
    }
    let executableDocument = document;
    descriptionRanges.sort((left, right) => right.start - left.start);
    for (const range of descriptionRanges) {
      executableDocument =
        executableDocument.slice(0, range.start) +
        executableDocument.slice(range.end);
    }
    return stripIgnoredCharacters(executableDocument);
  });
}
