struct SwiftConformanceName {
    let source: String

    var includesDecodable: Bool {
        switch source {
        case "Codable", "Decodable", "Swift.Codable", "Swift.Decodable": true
        default: false
        }
    }

    var includesEncodable: Bool {
        switch source {
        case "Codable", "Encodable", "Swift.Codable", "Swift.Encodable": true
        default: false
        }
    }

    var includesSendable: Bool {
        switch source {
        case "Sendable", "Swift.Sendable", "@unchecked Sendable", "@unchecked Swift.Sendable": true
        default: false
        }
    }

    var usesCodingKeys: Bool {
        switch source {
        case "Codable", "Decodable", "Encodable",
             "Swift.Codable", "Swift.Decodable", "Swift.Encodable": true
        default: false
        }
    }
}
