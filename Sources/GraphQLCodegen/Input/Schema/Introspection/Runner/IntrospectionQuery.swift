import Foundation

struct IntrospectionQuery: Encodable {
    let query: String

    init(includeDeprecated: Bool) {
        let includeDeprecatedArgument = includeDeprecated ? "true" : "false"
        query = """
        query IntrospectionQuery {
          __schema {
            description
            queryType {
              name
              kind
            }
            mutationType {
              name
              kind
            }
            subscriptionType {
              name
              kind
            }
            types {
              ...FullType
            }
            directives {
              name
              description
              locations
              isRepeatable
              args(includeDeprecated: \(includeDeprecatedArgument)) {
                ...InputValue
              }
            }
          }
        }

        fragment FullType on __Type {
          kind
          name
          description
          specifiedByURL
          isOneOf
          fields(includeDeprecated: \(includeDeprecatedArgument)) {
            name
            description
            args(includeDeprecated: \(includeDeprecatedArgument)) {
              ...InputValue
            }
            type {
              ...TypeRef
            }
            isDeprecated
            deprecationReason
          }
          inputFields(includeDeprecated: \(includeDeprecatedArgument)) {
            ...InputValue
          }
          interfaces {
            ...TypeRef
          }
          enumValues(includeDeprecated: \(includeDeprecatedArgument)) {
            name
            description
            isDeprecated
            deprecationReason
          }
          possibleTypes {
            ...TypeRef
          }
        }

        fragment InputValue on __InputValue {
          name
          description
          type {
            ...TypeRef
          }
          defaultValue
          isDeprecated
          deprecationReason
        }

        fragment TypeRef on __Type {
          kind
          name
          ofType {
            kind
            name
            ofType {
              kind
              name
              ofType {
                kind
                name
                ofType {
                  kind
                  name
                  ofType {
                    kind
                    name
                    ofType {
                      kind
                      name
                      ofType {
                        kind
                        name
                        ofType {
                          kind
                          name
                          ofType {
                            kind
                            name
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        """.components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
