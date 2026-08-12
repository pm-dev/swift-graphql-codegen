import Foundation

struct DocumentScanner {
    struct DocumentFile {
        let relativePath: String
        let url: URL
    }

    enum DocumentFileFinderError: Error, CustomStringConvertible {
        case duplicateFilename(String, URL, URL)
        case failedToEnumerateDirectory(URL)

        var description: String {
            switch self {
            case .duplicateFilename(let filename, let first, let second):
                """
                GraphQL document filenames must be unique when using a shared output directory:
                Filename: \(filename)
                Sources:
                \(first.path)
                \(second.path)
                """
            case .failedToEnumerateDirectory(let directory):
                "Failed to enumerate GraphQL document directory: \(directory.path)"
            }
        }
    }

    let directories: [URL]

    func scan(
        excluding excludedURL: URL?,
        requiringUniqueFilenames: Bool
    ) throws -> [DocumentFile] {
        let excludedURL = excludedURL?.standardizedFileURL
        var documentByURL: [URL: (document: DocumentFile, sourceRootDepth: Int)] = [:]
        for directory in directories.sorted(by: { $0.path < $1.path }) {
            let sourceRoot = directory.standardizedFileURL.pathComponents
            for url in try scanDirectory(directory) {
                let standardizedURL = url.standardizedFileURL
                if let excludedURL, standardizedURL == excludedURL {
                    continue
                }
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
        let documents = documentByURL
            .sorted { $0.key.path < $1.key.path }
            .map(\.value.document)
        guard requiringUniqueFilenames else {
            return documents
        }
        var documentByFilename: [String: URL] = [:]
        for document in documents {
            let filename = document.url.lastPathComponent
            if let existingDocument = documentByFilename[filename] {
                throw DocumentFileFinderError.duplicateFilename(filename, existingDocument, document.url)
            }
            documentByFilename[filename] = document.url
        }
        return documents
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
