import Foundation

struct DocumentScanner {
    enum DocumentFileFinderError: Error {
        case failedToEnumerateDirectory(URL)
    }

    let directories: [URL]

    func scan() throws -> DocumentScan {
        try directories
            .map(scanDirectory)
            .reduce(into: DocumentScan()) { result, scan in
                result.documentFileURLs.append(contentsOf: scan.documentFileURLs)
                result.generatedFileURLs.append(contentsOf: scan.generatedFileURLs)
            }
    }

    private func scanDirectory(_ directory: URL) throws -> DocumentScan {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]
        guard let directoryEnumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: .skipsHiddenFiles
        )
        else {
            throw DocumentFileFinderError.failedToEnumerateDirectory(directory)
        }
        var documentFileURLs: [URL] = []
        var generatedFileURLs: [URL] = []
        for case let url as URL in directoryEnumerator
            where try url.resourceValues(forKeys: resourceKeys).isRegularFile == true {
            switch url {
            case let url where url.pathExtension == "graphql": documentFileURLs.append(url)
            case let url where url.lastPathComponent.hasSuffix(".graphql.swift"): generatedFileURLs.append(url)
            default: break
            }
        }
        return DocumentScan(
            documentFileURLs: documentFileURLs,
            generatedFileURLs: generatedFileURLs
        )
    }
}
