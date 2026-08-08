import Foundation

final class HideSelectedRequestHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        ActionInputLoader.loadURLs(from: context) { result in
            do {
                let scopedURLs = try result.get()
                try FinderFileOperations.hide(scopedURLs.urls)
                context.completeRequest(returningItems: nil)
                _ = scopedURLs
            } catch {
                context.cancelRequest(withError: error)
            }
        }
    }
}
