import Foundation

final class UnhideFolderContentsRequestHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        ActionInputLoader.loadURLs(from: context) { result in
            do {
                let scopedURLs = try result.get()
                try FinderFileOperations.unhideDirectChildren(of: scopedURLs.urls)
                context.completeRequest(returningItems: nil)
                _ = scopedURLs
            } catch {
                context.cancelRequest(withError: error)
            }
        }
    }
}
