extension String {
    subscript(_ range: Range<Int>) -> Substring {
        self[
            String.Index(utf16Offset: range.lowerBound, in: self)..<
            String.Index(utf16Offset: range.upperBound, in: self)
        ]
    }
}
