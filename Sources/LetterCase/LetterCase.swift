import Foundation

public enum LetterCase: String, Sendable {
    case regular // No transformation applied.
    case capitalized // e.g. Capitalized Case
    case kebab // e.g. kebab-case
    case lower // e.g. lower case
    case lowerCamel = "lower-camel" // e.g. lowerCamelCase
    case macro // e.g. MACRO_CASE
    case train // e.g. TRAIN-CASE
    case snake // e.g. snake_case
    case upper // e.g. UPPER CASE
    case upperCamel = "upper-camel" // e.g. UpperCamelCase

    public typealias Options = LetterCaseOptions
}

extension LetterCase: CustomStringConvertible {
    public var description: String {
        switch self {
        case .capitalized:
            "Capitalized"
        case .kebab:
            "Kebab case"
        case .lower:
            "Lower case"
        case .lowerCamel:
            "Lower camel case"
        case .macro:
            "Macro case"
        case .regular:
            "Regular"
        case .snake:
            "Snake case"
        case .train:
            "Train case"
        case .upper:
            "Upper case"
        case .upperCamel:
            "Upper camel case"
        }
    }
}
