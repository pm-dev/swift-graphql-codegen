//
//  GraphQLID.swift
//  GraphQL
//
//  Created by Peter Meyers on 8/11/26.
//

public struct GraphQLID: Codable, Hashable, Sendable {
    private let value: String

    public init(from decoder: Decoder) throws {
        value = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
