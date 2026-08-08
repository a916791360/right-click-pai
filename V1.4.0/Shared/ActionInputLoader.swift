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

        loadURLs(from: providers, completion: completion)
    }

    static func loadURLs(
        from providers: [NSItemProvider],
        completion: @escaping (Result<ScopedURLs, Error>) -> Void
    ) {
        let requests = providers.compactMap { provider -> (NSItemProvider, String)? in
            guard let typeIdentifier = preferredTypeIdentifier(for: provider) else {
                return nil
            }
            return (provider, typeIdentifier)
        }

        guard !requests.isEmpty else {
            completion(.failure(SuperRightClickError.noInput))
            return
        }

        let group = DispatchGroup()
        let stateQueue = DispatchQueue(label: "com.qingmeng.SuperRightClick.input-loader")
        var resolvedURLs = Array<URL?>(repeating: nil, count: requests.count)
        var firstError: Error?

        for (index, request) in requests.enumerated() {
            group.enter()
            loadOriginalURL(from: request.0, typeIdentifier: request.1) { result in
                stateQueue.sync {
                    switch result {
                    case let .success(url):
                        resolvedURLs[index] = url
                    case let .failure(error):
                        if firstError == nil {
                            firstError = error
                        }
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
            guard urls.count == requests.count else {
                completion(.failure(SuperRightClickError.unsupportedInput))
                return
            }
            completion(.success(ScopedURLs(urls: urls)))
        }
    }

    private static func preferredTypeIdentifier(for provider: NSItemProvider) -> String? {
        if let fileType = provider.registeredTypeIdentifiers.first(where: { identifier in
            UTType(identifier)?.conforms(to: .item) == true
        }) {
            return fileType
        }

        return [UTType.fileURL.identifier, UTType.plainText.identifier].first(where: {
            provider.hasItemConformingToTypeIdentifier($0)
        })
    }

    private static func loadOriginalURL(
        from provider: NSItemProvider,
        typeIdentifier: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        provider.loadInPlaceFileRepresentation(forTypeIdentifier: typeIdentifier) { fileURL, isInPlace, error in
            if let fileURL, isInPlace {
                completion(.success(fileURL))
                return
            }

            let fallbackType = [UTType.fileURL.identifier, UTType.plainText.identifier].first(where: {
                provider.hasItemConformingToTypeIdentifier($0)
            })

            guard let fallbackType else {
                completion(.failure(error ?? SuperRightClickError.unsupportedInput))
                return
            }

            provider.loadItem(forTypeIdentifier: fallbackType, options: nil) { item, fallbackError in
                if let url = url(from: item) {
                    completion(.success(url))
                } else {
                    completion(.failure(fallbackError ?? error ?? SuperRightClickError.unsupportedInput))
                }
            }
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
