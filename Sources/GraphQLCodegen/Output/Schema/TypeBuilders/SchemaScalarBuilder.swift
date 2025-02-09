struct SchemaScalarBuilder: SwiftTypeBuildable {
    let scalar: Schema.Scalar

    func build(configuration: Configuration) -> [String] {
        var lines: [String] = []
        if let description = scalar.ast.description {
            for line in description.components(separatedBy: .newlines) {
                lines.append("/// \(line)")
            }
        }
        if let specifiedByURL = scalar.ast.specifiedByURL {
            lines.append("/// @specifiedBy \(specifiedByURL)")
        }
        let isPublic = configuration.output.schema.accessLevel == .public
        lines.append("\(isPublic ? "public " : "")typealias \(scalar.ast.name) = String")
        return lines
    }
}
