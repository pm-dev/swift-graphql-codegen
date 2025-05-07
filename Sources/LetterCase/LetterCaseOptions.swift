import Foundation

public struct LetterCaseOptions: OptionSet, Sendable {
    public static let preserveSuffix = LetterCaseOptions(rawValue: 1 << 0)
    public static let preservePunctuation = LetterCaseOptions(rawValue: 1 << 1)
    public static let stripPunctuation = LetterCaseOptions(rawValue: 1 << 2)

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}
