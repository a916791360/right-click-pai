import AppKit
import Foundation

final class CopyPathRequestHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        ActionInputLoader.loadURLs(from: context) { result in
            do {
                let scopedURLs = try result.get()
                let text = PathTextFormatter.text(for: scopedURLs.urls)
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                guard pasteboard.setString(text, forType: .string) else {
                    throw SuperRightClickError.clipboardWriteFailed
                }
                context.completeRequest(returningItems: nil)
                _ = scopedURLs
            } catch {
                context.cancelRequest(withError: error)
            }
        }
    }
}
