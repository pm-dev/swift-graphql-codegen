struct SwiftConformanceName {
    let source: String

    var includesDecodable: Bool {
        switch source {
        case "Codable", "Decodable", "Swift.Codable", "Swift.Decodable": true
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
