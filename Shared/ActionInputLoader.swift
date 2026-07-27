import Foundation
import UniformTypeIdentifiers

final class ScopedURLs {
    let urls: [URL]
    private let accessedURLs: [URL]

    init(urls: [URL]) {
        self.urls = urls
        self.accessedURLs = urls.filter { $0.startAccessingSecurityScopedResource() }
    }

    deinit {
        accessedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
    }
}

enum ActionInputLoader {
    static func loadURLs(
        from context: NSExtensionContext,
        completion: @escaping (Result<ScopedURLs, Error>) -> Void
    ) {
        let providers = context.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] }
            .filter { provider in
                provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                    || provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
            }

        guard !providers.isEmpty else {
            completion(.failure(SuperRightClickError.noInput))
            return
        }

        let group = DispatchGroup()
        let stateQueue = DispatchQueue(label: "com.qingmeng.SuperRightClick.input-loader")
        var resolvedURLs = Array<URL?>(repeating: nil, count: providers.count)
        var firstError: Error?

        for (index, provider) in providers.enumerated() {
            group.enter()
            let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                ? UTType.fileURL.identifier
                : UTType.plainText.identifier
            provider.loadItem(
                forTypeIdentifier: typeIdentifier,
                options: nil
            ) { item, error in
                stateQueue.sync {
                    if let url = url(from: item) {
                        resolvedURLs[index] = url
                    } else if firstError == nil {
                        firstError = error ?? SuperRightClickError.unsupportedInput
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
                return
            }

            let urls = resolvedURLs.compactMap { $0 }
            guard urls.count == providers.count else {
                completion(.failure(SuperRightClickError.unsupportedInput))
                return
            }
            completion(.success(ScopedURLs(urls: urls)))
        }
    }

    static func url(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let data = item as? Data {
            if let path = String(data: data, encoding: .utf8) {
                if let url = URL(string: path), url.isFileURL {
                    return url
                }
                return URL(fileURLWithPath: path)
            }
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        if let path = item as? String {
            if let url = URL(string: path), url.isFileURL {
                return url
            }
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}
