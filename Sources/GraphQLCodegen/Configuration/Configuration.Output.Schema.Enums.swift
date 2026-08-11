extension Configuration.Output.Schema {
    /// Options controlling the code generated to represent enum types
    public struct Enums: Sendable {
        /// Call this function to create a new `Enums` instance.
        ///
        /// - Parameters:
        ///   - conformances: A list of protocols each generated enum will conform to.
        ///   - caseConversion: Optionally, the letter casing that enum cases should be converted to.
        /// - Returns: A new `Enums` instance to be passed to the `Schema.schema` factory function.
        public static func enums(
            conformances: [String] = ["Encodable", "Sendable"],
            caseConversion: CaseConversion? = nil
        ) -> Enums {
            Enums(
                conformances: conformances,
                caseConversion: caseConversion
            )
        }

        public var conformances: [String]
        public var caseConversion: CaseConversion?
    }
}

extension Configuration.Output.Schema.Enums {
    /// Type of letter casing to convert enum cases to
    /// For example, an enum in a GQL schema may define the option `NORTH_WEST`
    /// If a CaseConversion is used, it must specify `from: .macro` and `to` may be any case.
    /// If `lowerCamel` is used, this codegen would create `case northWest`
    public struct CaseConversion: Sendable {
        public enum Case: Sendable {
            case lowerCamel // thisIsCamelCase
            case macro // THIS_IS_MACRO_CASE
        }

        public var from: Case
        public var to: Case
        public static func conversion(from: Case, to: Case) -> CaseConversion {
            CaseConversion(
                from: from,
                to: to
            )
        }

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
