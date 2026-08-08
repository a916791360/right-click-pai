import AppKit
import FinderSync

final class FinderSync: FIFinderSync {
    private let controller = FIFinderSyncController.default()

    override init() {
        super.init()
        controller.directoryURLs = [URL(fileURLWithPath: "/", isDirectory: true)]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        switch menuKind {
        case .contextualMenuForItems:
            return selectedItemsMenu()
        case .contextualMenuForContainer:
            return currentFolderMenu()
        default:
            return nil
        }
    }

    private func selectedItemsMenu() -> NSMenu? {
        guard controller.selectedItemURLs()?.isEmpty == false else { return nil }

        let menu = NSMenu()
        if FinderMenuSettings.isEnabled(.copyPath) {
            menu.addItem(menuItem(
                title: "拷贝路径",
                symbol: "doc.on.doc",
                action: #selector(copySelectedPaths(_:))
            ))
        }
        if FinderMenuSettings.isEnabled(.moveTo) {
            menu.addItem(menuItem(
                title: "移动到…",
                symbol: "folder",
                action: #selector(moveSelectedItems(_:))
            ))
        }
        if FinderMenuSettings.isEnabled(.hideSelected) {
            menu.addItem(menuItem(
                title: "隐藏已选项目",
                symbol: "eye.slash",
                action: #selector(hideSelectedItems(_:))
            ))
        }
        if FinderMenuSettings.isEnabled(.openInTerminal) {
            menu.addItem(menuItem(
                title: "进入终端",
                symbol: "terminal",
                action: #selector(openInTerminal(_:))
            ))
        }
        return menu.items.isEmpty ? nil : menu
    }

    private func currentFolderMenu() -> NSMenu? {
        guard FinderMenuSettings.isEnabled(.unhideFolderContents) else { return nil }

        let menu = NSMenu()
        menu.addItem(menuItem(
            title: "取消隐藏当前文件夹内全部项目",
            symbol: "eye",
            action: #selector(unhideCurrentFolder(_:))
        ))
        return menu
    }

    @IBAction private func copySelectedPaths(_ sender: AnyObject?) {
        guard let urls = selectedItemURLs() else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(PathTextFormatter.text(for: urls), forType: .string) else {
            showError(title: "拷贝路径失败", message: SuperRightClickError.clipboardWriteFailed.localizedDescription)
            return
        }
    }

    @IBAction private func moveSelectedItems(_ sender: AnyObject?) {
        guard let urls = selectedItemURLs() else { return }

        do {
            let identifier = try MoveRequestStore.create(for: urls)
            let didOpen = NSWorkspace.shared.open(MoveRequestStore.deepLink(for: identifier))
            guard didOpen else {
                MoveRequestStore.discard(identifier)
                showError(
                    title: "无法打开移动窗口",
                    message: "请确认右键派仍安装在“应用程序”文件夹中，然后重试。"
                )
                return
            }
        } catch {
            showError(title: "无法开始移动", message: error.localizedDescription)
        }
    }

    @IBAction private func openInTerminal(_ sender: AnyObject?) {
        guard let urls = selectedItemURLs() else { return }

        do {
            let identifier = try TerminalRequestStore.create(for: urls)
            let didOpen = NSWorkspace.shared.open(TerminalRequestStore.deepLink(for: identifier))
            guard didOpen else {
                TerminalRequestStore.discard(identifier)
                showError(
                    title: "无法打开终端",
                    message: "请确认右键派仍安装在“应用程序”文件夹中，然后重试。"
                )
                return
            }
        } catch {
            showError(title: "无法开始进入终端", message: error.localizedDescription)
        }
    }

    @IBAction private func hideSelectedItems(_ sender: AnyObject?) {
        guard let urls = selectedItemURLs() else { return }

        do {
            try FinderFileOperations.hide(urls)
        } catch {
            showError(title: "隐藏失败", message: error.localizedDescription)
        }
    }

    @IBAction private func unhideCurrentFolder(_ sender: AnyObject?) {
        guard let folder = controller.targetedURL() else {
            showError(title: "取消隐藏失败", message: "无法读取当前 Finder 文件夹。")
            return
        }

        do {
            try FinderFileOperations.unhideDirectChildren(of: [folder])
            NSWorkspace.shared.noteFileSystemChanged(folder.path)
        } catch {
            showError(title: "取消隐藏失败", message: error.localizedDescription)
        }
    }

    private func selectedItemURLs() -> [URL]? {
        guard let urls = controller.selectedItemURLs(), !urls.isEmpty else {
            showError(title: "操作失败", message: "无法读取 Finder 当前选中的项目。")
            return nil
        }
        return urls
    }

    private func menuItem(title: String, symbol: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
