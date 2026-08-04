extension String {
    subscript(utf16Range range: Range<Int>) -> Substring {
        self[
            String.Index(utf16Offset: range.lowerBound, in: self)..<
            String.Index(utf16Offset: range.upperBound, in: self)
        ]
    }

    var capitalizedFirst: String {
        prefix(1).capitalized + dropFirst()
    }
}
