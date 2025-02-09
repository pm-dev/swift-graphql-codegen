import Foundation

struct SwiftFileWriter {
    private var header: String?
    private var imports: [String] = []
    private var types: [SwiftTypeBuildable] = []

    func write(to file: URL, configuration: Configuration) async throws {
        var lines: [String] = []
        if let header {
            lines.append(header)
        }
        lines.append(contentsOf: imports)
        lines.append("")
        for type in types {
            lines.append(contentsOf: type.build(configuration: configuration))
            lines.append("")
        }
        try await FileOutput.default.write(lines, to: file)
    }

    mutating func setHeader(_ header: String?) {
        self.header = header
    }

    mutating func setImports(_ importedModules: any Sequence<String>) {
        var imports: Set<String> = []
        for importedModule in importedModules {
            imports.insert("import " + importedModule)
        }
        self.imports = imports.sorted()
    }

    mutating func addType(_ type: SwiftTypeBuildable) {
        types.append(type)
    }
}
