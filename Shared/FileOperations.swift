import AppKit
import Foundation

enum PathTextFormatter {
    static func text(for urls: [URL]) -> String {
        urls.map(\.path).joined(separator: "\n")
    }
}

enum FinderFileOperations {
    static func hide(_ urls: [URL]) throws {
        var failures: [(URL, Error)] = []
        for url in urls {
            do {
                try setHidden(true, for: url)
                NSWorkspace.shared.noteFileSystemChanged(url.deletingLastPathComponent().path)
            } catch {
                failures.append((url, error))
            }
        }
        if !failures.isEmpty {
            throw SuperRightClickError.partialFailure(action: "隐藏", failures: failures)
        }
    }

    static func unhideDirectChildren(of folders: [URL]) throws {
        var failures: [(URL, Error)] = []
        for folder in folders {
            do {
                let values = try folder.resourceValues(forKeys: [.isDirectoryKey])
                guard values.isDirectory == true else {
                    throw SuperRightClickError.foldersOnly
                }
                try unhideDirectChildren(of: folder)
                NSWorkspace.shared.noteFileSystemChanged(folder.path)
            } catch {
                failures.append((folder, error))
            }
        }
        if !failures.isEmpty {
            throw SuperRightClickError.partialFailure(action: "取消隐藏", failures: failures)
        }
    }

    private static func unhideDirectChildren(of folder: URL) throws {
        let keys: [URLResourceKey] = [.isHiddenKey]
        let children = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: keys,
            options: []
        )

        var failures: [(URL, Error)] = []
        for child in children where !child.lastPathComponent.hasPrefix(".") {
            do {
                let values = try child.resourceValues(forKeys: Set(keys))
                if values.isHidden == true {
                    try setHidden(false, for: child)
                }
            } catch {
                failures.append((child, error))
            }
        }
        if !failures.isEmpty {
            throw SuperRightClickError.partialFailure(action: "取消隐藏", failures: failures)
        }
    }

    private static func setHidden(_ hidden: Bool, for url: URL) throws {
        var mutableURL = url
        var values = URLResourceValues()
        values.isHidden = hidden
        try mutableURL.setResourceValues(values)
    }
}
