struct SwiftTypeReference: Hashable {
    enum Module: String {
        case cryptoKit = "CryptoKit"
        case foundation = "Foundation"
        case swift = "Swift"
    }

    let module: Module
    let name: SwiftTypeIdentifier

    init(_ module: Module, _ name: String) {
        self.module = module
        self.name = SwiftTypeIdentifier(swiftName: name)
    }

    init?(nativeScalarName: String) {
        guard ["Bool", "Double", "Int", "String"].contains(nativeScalarName) else {
            return nil
        }
        self.init(.swift, nativeScalarName)
    }
}

struct SwiftTypeScope {
    private let declarations: Set<SwiftTypeIdentifier>

    init<S: Sequence>(declarations: S) where S.Element == SwiftTypeIdentifier {
        self.declarations = Set(declarations)
    }

    func adding<S: Sequence>(declarations: S) -> SwiftTypeScope where S.Element == SwiftTypeIdentifier {
        SwiftTypeScope(declarations: self.declarations.union(declarations))
    }

    func conformance(_ source: String) -> String {
        source
    }

    func reference(_ reference: SwiftTypeReference) -> String {
        reference.name.source
    }

    func qualify(_ source: String, references _: Set<SwiftTypeReference>) -> String {
        source
    }
}
