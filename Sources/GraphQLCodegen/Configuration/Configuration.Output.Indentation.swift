extension Configuration.Output {
    /// Controls whether indentation in generation files uses spaces or a tab
    public enum Indentation: Sendable {
        /// Indentation will use the \t character
        case tab

        /// Indentation will use the given number of spaces
        case spaces(Int)

        var string: String {
            switch self {
            case .tab: "\t"
            case .spaces(let int): String(repeating: " ", count: int)
            }
        }
    }
}
