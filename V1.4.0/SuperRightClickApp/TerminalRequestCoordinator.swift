import AppKit
import Foundation

@MainActor
final class TerminalRequestCoordinator {
    func handle(_ deepLink: URL, completion: @escaping () -> Void) {
        guard let identifier = TerminalRequestStore.identifier(from: deepLink) else {
            completion()
            return
        }

        do {
            let urls = try TerminalRequestStore.consume(identifier)
            openTerminals(for: urls)
        } catch {
            showError(title: "无法进入终端", message: error.localizedDescription)
        }
        completion()
    }

    private func openTerminals(for urls: [URL]) {
        // 文件夹直接进入；文件进入其所在目录；去重并保持顺序。
        var directories: [URL] = []
        for url in urls {
            var isDirectory: ObjCBool = false
            let target = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                && isDirectory.boolValue
                ? url
                : url.deletingLastPathComponent()
            if !directories.contains(target) {
                directories.append(target)
            }
        }

        for directory in directories {
            do {
                try openTerminal(at: directory)
            } catch {
                showError(title: "无法进入终端", message: error.localizedDescription)
            }
        }
    }

    private func openTerminal(at directory: URL) throws {
        // 使用 open -a Terminal 直接以目标目录作为工作目录打开终端：
        // 终端打开后已位于该目录（窗口标题与提示符均显示目录名），
        // 不在命令行中回显 cd 命令，与主流 Finder 增强工具一致。
        try run(
            executable: "/usr/bin/open",
            arguments: ["-a", "Terminal", directory.path]
        )
    }

    private func run(executable: String, arguments: [String]) throws {
        let process = Process()
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardError = standardError
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
            let message = String(decoding: errorData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw SuperRightClickError.commandFailed(
                message.isEmpty ? "系统未能打开终端。" : message
            )
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
