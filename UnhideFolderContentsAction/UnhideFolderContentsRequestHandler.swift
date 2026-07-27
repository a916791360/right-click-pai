import AppKit
import FinderSync

final class FinderSync: FIFinderSync {
    private let controller = FIFinderSyncController.default()

    override init() {
        super.init()
        controller.directoryURLs = [URL(fileURLWithPath: "/", isDirectory: true)]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForContainer else {
            return nil
        }

        let menu = NSMenu()
        let item = NSMenuItem(
            title: "取消隐藏当前文件夹内全部项目",
            action: #selector(unhideCurrentFolder(_:)),
            keyEquivalent: ""
        )
        menu.addItem(item)
        return menu
    }

    @IBAction private func unhideCurrentFolder(_ sender: AnyObject?) {
        guard let folder = controller.targetedURL() else {
            showError("无法读取当前 Finder 文件夹。")
            return
        }

        do {
            try FinderFileOperations.unhideDirectChildren(of: [folder])
            NSWorkspace.shared.noteFileSystemChanged(folder.path)
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "取消隐藏失败"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
