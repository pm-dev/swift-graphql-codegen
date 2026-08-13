extension Configuration.Output.Schema.Enums {
    /// Type of letter casing to convert enum cases to
    /// For example, an enum in a GQL schema may define the option `NORTH_WEST`
    /// If a CaseConversion is used, it must specify `from: .macro` and `to` may be any case.
    /// If `lowerCamel` is used, this codegen would create `case northWest`
    public struct CaseConversion: Sendable {
        public static func conversion(from: Case, to: Case) -> CaseConversion {
            CaseConversion(
                from: from,
                to: to
            )
        }

        public var from: Case
        public var to: Case

        func convert(_ value: String) -> String {
            let words = from.words(in: value)
            switch to {
            case .lowerCamel:
                guard let first = words.first else { return "" }
                return first.lowercased() + words.dropFirst().map { word in
                    word.prefix(1).uppercased() + word.dropFirst().lowercased()
                }.joined()
            case .macro:
                return words.map { $0.uppercased() }.joined(separator: "_")
            }
        }
    }
}

extension Configuration.Output.Schema.Enums.CaseConversion.Case {
    fileprivate func words(in value: String) -> [Substring] {
        switch self {
        case .lowerCamel:
            var words: [Substring] = []
            var wordStart = value.startIndex
            for index in value.indices.dropFirst() where value[index].isUppercase {
                words.append(value[wordStart..<index])
                wordStart = index
            }
            words.append(value[wordStart...])
            return words.filter { !$0.isEmpty }
        case .macro:
            return value.split(separator: "_")
        }
    }
}
