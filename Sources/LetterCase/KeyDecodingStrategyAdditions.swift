import Foundation

struct AnyKey: CodingKey {
    static let empty = AnyKey(string: "")

    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }

    init(string: String) {
        self.stringValue = string
        self.intValue = nil
    }
}

extension JSONDecoder.KeyDecodingStrategy {
    // MARK: - Aliases

    public static let convertFromCapitalized = letterCaseStrategy(for: .capitalized)
    public static let convertFromDashCase = letterCaseStrategy(for: .kebab)
    public static let convertFromKebabCase = letterCaseStrategy(for: .kebab)
    public static let convertFromLispCase = letterCaseStrategy(for: .kebab)
    public static let convertFromLowerCase = letterCaseStrategy(for: .lower)
    public static let convertFromLowerCamelCase = letterCaseStrategy(for: .lowerCamel)
    public static let convertFromMacroCase = letterCaseStrategy(for: .macro)
    public static let convertFromScreamingSnakeCase = letterCaseStrategy(for: .macro)
    public static let convertFromTrainCase = letterCaseStrategy(for: .train)
    public static let convertFromUpperCase = letterCaseStrategy(for: .upper)
    public static let convertFromUpperCamelCase = letterCaseStrategy(for: .upperCamel)

    // MARK: - Conversion

    public static func letterCaseStrategy(
        from letterCase: LetterCase,
        to newLetterCase: LetterCase
    ) -> JSONDecoder.KeyDecodingStrategy {
        JSONDecoder.KeyDecodingStrategy.custom { keys in
            // Should never receive an empty `keys` array in theory.
            guard let lastKey = keys.last else {
                return AnyKey.empty
            }
            // Represents an array index.
            if lastKey.intValue != nil {
                return lastKey
            }
            let newLetterCaseKey = lastKey.stringValue.convert(from: letterCase, to: newLetterCase)
            return AnyKey(string: newLetterCaseKey)
        }
    }

    public static func letterCaseStrategy(for letterCase: LetterCase) -> JSONDecoder.KeyDecodingStrategy {
        letterCaseStrategy(from: letterCase, to: .lowerCamel)
    }
}

extension JSONEncoder.KeyEncodingStrategy {
    // MARK: - Aliases

    public static let convertToCapitalized = letterCaseStrategy(for: .capitalized)
    public static let convertToDashCase = letterCaseStrategy(for: .kebab)
    public static let convertToKebabCase = letterCaseStrategy(for: .kebab)
    public static let convertToLispCase = letterCaseStrategy(for: .kebab)
    public static let convertToLowerCase = letterCaseStrategy(for: .lower)
    public static let convertToLowerCamelCase = letterCaseStrategy(for: .lowerCamel)
    public static let convertToMacroCase = letterCaseStrategy(for: .macro)
    public static let convertToScreamingSnakeCase = letterCaseStrategy(for: .macro)
    public static let convertToTrainCase = letterCaseStrategy(for: .train)
    public static let convertToUpperCase = letterCaseStrategy(for: .upper)
    public static let convertToUpperCamelCase = letterCaseStrategy(for: .upperCamel)

    // MARK: - Conversion

    public static func letterCaseStrategy(
        from letterCase: LetterCase,
        to newLetterCase: LetterCase
    ) -> JSONEncoder.KeyEncodingStrategy {
        JSONEncoder.KeyEncodingStrategy.custom { keys in
            // Should never receive an empty `keys` array in theory.
            guard let lastKey = keys.last else {
                return AnyKey.empty
            }
            // Represents an array index.
            if lastKey.intValue != nil {
                return lastKey
            }
            let newLetterCaseKey = lastKey.stringValue.convert(from: letterCase, to: newLetterCase)
            return AnyKey(string: newLetterCaseKey)
        }
    }

    public static func letterCaseStrategy(for letterCase: LetterCase) -> JSONEncoder.KeyEncodingStrategy {
        letterCaseStrategy(from: .lowerCamel, to: letterCase)
    }
}
