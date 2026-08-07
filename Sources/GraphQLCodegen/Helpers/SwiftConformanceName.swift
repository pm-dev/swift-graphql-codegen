struct SwiftConformanceName {
    private static let standardLibraryNames: Set<String> = [
        "CaseIterable",
        "Codable",
        "CodingKey",
        "Comparable",
        "CustomStringConvertible",
        "Decodable",
        "Encodable",
        "Equatable",
        "Error",
        "Hashable",
        "Identifiable",
        "OptionSet",
        "RawRepresentable",
        "Sendable",
    ]

    let source: String

    var standardLibraryReference: SwiftTypeReference? {
        let name = source.hasPrefix("Swift.") ? String(source.dropFirst("Swift.".count)) : source
        guard Self.standardLibraryNames.contains(name) else { return nil }
        return SwiftTypeReference(.swift, name)
    }

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

    var lookupTypeName: SwiftTypeIdentifier? {
        source.split(separator: ".").first.map { component in
            SwiftTypeIdentifier(swiftName: String(component))
        }
    }

    var moduleQualifier: SwiftTypeIdentifier? {
        guard standardLibraryReference == nil else { return nil }
        guard source.contains(".") else { return nil }
        return lookupTypeName
    }
}
