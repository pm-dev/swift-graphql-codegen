extension String {
    subscript(_ range: Range<Int>) -> Substring {
        self[
            index(startIndex, offsetBy: range.startIndex)..<index(startIndex, offsetBy: range.endIndex)
        ]
    }

    var capitalizedFirst: String {
        prefix(1).capitalized + dropFirst()
    }
}
