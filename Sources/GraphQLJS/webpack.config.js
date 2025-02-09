const path = require('path');

module.exports = {
  entry: './index.js',
  mode: 'production',
  output: {
    path: path.resolve(__dirname, '../GraphQLCodegenV2/Resources'),
    filename: 'graphql.bundle.js',
    library: 'GraphQL',
    libraryTarget: 'var',
  },
};
