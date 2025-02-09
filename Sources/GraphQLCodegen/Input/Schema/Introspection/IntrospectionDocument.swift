struct IntrospectionResponse: Decodable {
    struct Data: Decodable {
        let __schema: __Schema
    }

    let data: Data
}
