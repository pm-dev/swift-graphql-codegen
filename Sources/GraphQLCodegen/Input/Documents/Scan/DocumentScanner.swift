import Foundation

struct DocumentScanner {
    enum DocumentFileFinderError: Error {
        case failedToEnumerateDirectory(URL)
    }

    let directories: [URL]

    func scan() throws -> [URL] {
        let documentFileURLs = try directories
            .sorted { $0.path < $1.path }
            .map(scanDirectory)
            .flatMap { $0 }
        return Set(documentFileURLs).sorted { $0.path < $1.path }
    }

    private func scanDirectory(_ directory: URL) throws -> [URL] {
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
        for case let url as URL in directoryEnumerator
            where try url.resourceValues(forKeys: resourceKeys).isRegularFile == true {
            if url.pathExtension == "graphql" {
                documentFileURLs.append(url)
            }
        }
        return documentFileURLs
    }
}
