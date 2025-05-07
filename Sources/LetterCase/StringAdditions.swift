import Foundation

extension String {
    public func convert(
        from letterCase: LetterCase,
        to newLetterCase: LetterCase,
        options: LetterCase.Options = []
    ) -> String {
        switch letterCase {
        case .capitalized, .lower, .regular, .upper:
            convertFromCaseWith(separator: " ", to: newLetterCase, options: options)
        case .kebab, .train:
            convertFromCaseWith(separator: "-", to: newLetterCase, options: options)
        case .lowerCamel, .upperCamel:
            convertFromCaseWith(separator: nil, to: newLetterCase, options: options)
        case .macro, .snake:
            convertFromCaseWith(separator: "_", to: newLetterCase, options: options)
        }
    }
}

// Private API
extension String {
    private func capitalized(options: LetterCase.Options = [], separator: String.Element? = " ") -> String {
        var input = self
        if options.contains(.stripPunctuation) {
            input = stripPunctuation(input)
        }
        return capitalizeSubSequences(capitalizeFirst: true, conjunction: " ", options: options, separator: separator)
    }

    private func kebabCased(options: LetterCase.Options = [], separator: String.Element? = " ") -> String {
        var options: LetterCase.Options = options
        if !options.contains(.preservePunctuation) {
            options.update(with: .stripPunctuation)
        }
        return capitalizeSubSequences(capitalizeFirst: false, conjunction: "-", options: options, separator: separator)
    }

    private func lowerCased(options: LetterCase.Options = [], separator: String.Element? = " ") -> String {
        var input = self
        if options.contains(.stripPunctuation) {
            input = stripPunctuation(input)
        }
        return capitalizeSubSequences(capitalizeFirst: false, conjunction: " ", options: options, separator: separator)
            .lowercased()
    }

    private func lowerCamelCased(options: LetterCase.Options = [], separator: String.Element? = " ") -> String {
        var options: LetterCase.Options = options
        if !options.contains(.preservePunctuation) {
            options.update(with: .stripPunctuation)
        }
        let upperCamelCased = self.upperCamelCased(options: options, separator: separator)
        if let firstChar = upperCamelCased.first {
            return String(firstChar).lowercased() + String(upperCamelCased.dropFirst())
        }
        return upperCamelCased
    }

    private func macroCased(options: LetterCase.Options = [], separator: String.Element? = " ") -> String {
        var options: LetterCase.Options = [options]
        if !options.contains(.preservePunctuation) {
            options.update(with: .stripPunctuation)
        }
        return capitalizeSubSequences(capitalizeFirst: true, conjunction: "_", options: options, separator: separator)
            .uppercased()
    }

    private func snakeCased(options: LetterCase.Options = [], separator: String.Element? = " ") -> String {
        var options: LetterCase.Options = options
        if !options.contains(.preservePunctuation) {
            options.update(with: .stripPunctuation)
        }
        return capitalizeSubSequences(capitalizeFirst: false, conjunction: "_", options: options, separator: separator)
    }

    private func trainCased(options: LetterCase.Options = [], separator: String.Element? = " ") -> String {
        kebabCased(options: options, separator: separator).upperCased()
    }

    private func upperCamelCased(options: LetterCase.Options = [], separator: String.Element? = " ") -> String {
        var options: LetterCase.Options = options
        if !options.contains(.preservePunctuation) {
            options.update(with: .stripPunctuation)
        }
        return capitalizeSubSequences(capitalizeFirst: true, options: options, separator: separator)
    }

    private func upperCased(options: LetterCase.Options = [], separator: String.Element? = " ") -> String {
        var input = self
        if options.contains(.stripPunctuation) {
            input = stripPunctuation(input)
        }
        return capitalizeSubSequences(capitalizeFirst: true, conjunction: " ", options: options, separator: separator)
            .uppercased()
    }

    private func capitalizedSubSequences() -> [String.SubSequence] {
        let input = self
        var seqStartIndex = input.startIndex
        var subSequences: [String.SubSequence] = []
        for index in input.indices {
            let currentCharacter = input[index]
            if currentCharacter.isUppercase {
                if index != input.startIndex {
                    let seqEndIndex = input.index(before: index)
                    let subSequence = input[seqStartIndex...seqEndIndex]
                    subSequences.append(subSequence)
                }
                seqStartIndex = index
            }
        }
        let subSequence = input[seqStartIndex..<input.endIndex]
        subSequences.append(subSequence)
        return subSequences
    }

    private func capitalizeSubSequences(
        capitalizeFirst: Bool,
        conjunction: String = "",
        options: LetterCase.Options = [],
        separator: String.Element? = " "
    ) -> String {
        var result = ""
        let subSequences: [String.SubSequence] =
            if let separator {
                split(separator: separator)
            } else {
                capitalizedSubSequences()
            }
        for subSequence in subSequences {
            if let firstChar = subSequence.first {
                let prefixWithCase = capitalizeFirst ? String(firstChar).uppercased() : String(firstChar).lowercased()
                let suffix = String(subSequence.dropFirst())
                let suffixWithCase = options.contains(.preserveSuffix) ? suffix : suffix.lowercased()
                result += prefixWithCase + suffixWithCase + conjunction
            }
        }
        if !conjunction.isEmpty, !result.isEmpty {
            result = String(result.dropLast())
        }
        if options.contains(.stripPunctuation) {
            result = stripPunctuation(result, except: conjunction.first)
        }
        return result
    }

    private func convertFromCaseWith(
        separator: String.Element?,
        to letterCase: LetterCase,
        options: LetterCase.Options = []
    ) -> String {
        switch letterCase {
        case .capitalized:
            capitalized(options: options, separator: separator)
        case .kebab:
            kebabCased(options: options, separator: separator)
        case .lower:
            lowerCased(options: options, separator: separator)
        case .lowerCamel:
            lowerCamelCased(options: options, separator: separator)
        case .macro:
            macroCased(options: options, separator: separator)
        case .regular:
            self // No change
        case .snake:
            snakeCased(options: options, separator: separator)
        case .train:
            trainCased(options: options, separator: separator)
        case .upper:
            upperCased(options: options, separator: separator)
        case .upperCamel:
            upperCamelCased(options: options, separator: separator)
        }
    }

    /// Strips punctuation from the provided input `String` leaving only alphanumeric characters except
    /// for a given special character if one is specified.
    private func stripPunctuation(_ input: String, except: Character? = nil) -> String {
        let chars = input.compactMap {
            ($0.isLetter || $0.isWholeNumber || $0 == except) ? $0 : nil
        }
        return String(chars)
    }
}
