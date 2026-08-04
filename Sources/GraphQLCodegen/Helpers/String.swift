extension String {
    struct InvalidUTF16Range: Error, CustomStringConvertible {
        let range: Range<Int>

        var description: String {
            "The UTF-16 range \(range) does not identify valid String boundaries."
        }
    }

    func substring(utf16Range range: Range<Int>) throws -> Substring {
        let utf16 = utf16
        guard range.lowerBound >= 0,
              range.upperBound >= range.lowerBound,
              let utf16Start = utf16.index(
                  utf16.startIndex,
                  offsetBy: range.lowerBound,
                  limitedBy: utf16.endIndex
              ),
              let utf16End = utf16.index(
                  utf16.startIndex,
                  offsetBy: range.upperBound,
                  limitedBy: utf16.endIndex
              ),
              let start = String.Index(utf16Start, within: self),
              let end = String.Index(utf16End, within: self) else {
            throw InvalidUTF16Range(range: range)
        }
        return self[start..<end]
    }

    var capitalizedFirst: String {
        prefix(1).capitalized + dropFirst()
    }
}
