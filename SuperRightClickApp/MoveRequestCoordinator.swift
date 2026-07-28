import AppKit
import Foundation

@MainActor
final class MoveRequestCoordinator {
    private var panel: NSOpenPanel?

    func handle(_ deepLink: URL, completion: @escaping () -> Void) {
        guard let identifier = MoveRequestStore.identifier(from: deepLink) else {
            completion()
            return
        }

        do {
            let urls = try MoveRequestStore.consume(identifier)
            presentDestinationPicker(for: urls, completion: completion)
        } catch {
            showError(title: "无法开始移动", message: error.localizedDescription)
            completion()
        }
    }

    private func presentDestinationPicker(
        for urls: [URL],
        completion: @escaping () -> Void
    ) {
        guard panel == nil else {
            showError(title: "已有移动操作", message: "请先完成当前的目标文件夹选择。")
            completion()
            return
        }

        let panel = NSOpenPanel()
        panel.title = "移动到"
        panel.message = urls.count == 1
            ? "选择“\(urls[0].lastPathComponent)”的目标文件夹"
            : "选择这 \(urls.count) 个项目的目标文件夹"
        panel.prompt = "移动"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.resolvesAliases = true
        panel.directoryURL = urls.first?.deletingLastPathComponent()
        panel.level = .modalPanel
        panel.collectionBehavior.insert(.moveToActiveSpace)
        self.panel = panel

        NSApp.activate()
        panel.begin { [weak self, weak panel] response in
            guard let self else {
                completion()
                return
            }
            defer {
                self.panel = nil
                completion()
            }
            guard response == .OK, let destination = panel?.url else { return }

            do {
                try FinderFileOperations.move(urls, to: destination)
            } catch {
                self.showError(title: "移动失败", message: error.localizedDescription)
            }
        }

        // The request originates in Finder while this app has no visible window.
        // Bring the picker forward after AppKit has attached it to the application.
        DispatchQueue.main.async {
            NSApp.activate()
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
        }
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
