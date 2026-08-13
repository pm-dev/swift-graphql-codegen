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
            for line in "@specifiedBy \(specifiedByURL)".components(separatedBy: .newlines) {
                lines.append("/// \(line)")
            }
        }
        let isPublic = configuration.output.schema.accessLevel == .public
        let typeName = SwiftTypeIdentifier(swiftName: scalar.ast.name).source
        let scalarMapping = configuration.output.schema.scalars.scalarMapping[scalar.ast.name]
        var mappedType = scalarMapping?.typeName ?? "String"
        if let module = scalarMapping?.module, module.prefix {
            mappedType = "\(module.name).\(mappedType)"
        }
        lines.append("\(isPublic ? "public " : "")typealias \(typeName) = \(mappedType)")
        return lines
    }
}
