import Foundation

struct DocumentScanner {
    struct DocumentFile {
        let relativePath: String
        let url: URL
    }

    enum DocumentFileFinderError: Error {
        case failedToEnumerateDirectory(URL)
    }

    let directories: [URL]

    func scan() throws -> [DocumentFile] {
        var documentByURL: [URL: (document: DocumentFile, sourceRootDepth: Int)] = [:]
        for directory in directories.sorted(by: { $0.path < $1.path }) {
            let sourceRoot = directory.standardizedFileURL.pathComponents
            for url in try scanDirectory(directory) {
                let standardizedURL = url.standardizedFileURL
                let document = DocumentFile(
                    relativePath: standardizedURL.pathComponents
                        .dropFirst(sourceRoot.count)
                        .joined(separator: "/"),
                    url: url
                )
                if documentByURL[standardizedURL]?.sourceRootDepth ?? -1 < sourceRoot.count {
                    documentByURL[standardizedURL] = (document, sourceRoot.count)
                }
            }
        }
        return documentByURL
            .sorted { $0.key.path < $1.key.path }
            .map(\.value.document)
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
