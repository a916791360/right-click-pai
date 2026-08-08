import AppKit
import Foundation

enum PathTextFormatter {
    static func text(for urls: [URL]) -> String {
        urls.map(\.path).joined(separator: "\n")
    }
}

enum FinderFileOperations {
    static func move(_ urls: [URL], to destinationFolder: URL) throws {
        let destinationValues = try destinationFolder.resourceValues(forKeys: [.isDirectoryKey])
        guard destinationValues.isDirectory == true else {
            throw SuperRightClickError.destinationMustBeFolder
        }

        var failures: [(URL, Error)] = []
        var changedFolders = Set<URL>()
        for url in urls {
            do {
                try validateMove(of: url, to: destinationFolder)
                let destination = destinationFolder.appendingPathComponent(
                    url.lastPathComponent,
                    isDirectory: (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                )
                try FileManager.default.moveItem(at: url, to: destination)
                changedFolders.insert(url.deletingLastPathComponent())
                changedFolders.insert(destinationFolder)
            } catch {
                failures.append((url, error))
            }
        }

        for folder in changedFolders {
            NSWorkspace.shared.noteFileSystemChanged(folder.path)
        }
        if !failures.isEmpty {
            throw SuperRightClickError.partialFailure(action: "移动", failures: failures)
        }
    }

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

    private static func validateMove(of source: URL, to destinationFolder: URL) throws {
        let source = source.standardizedFileURL
        let destinationFolder = destinationFolder.standardizedFileURL
        let sourceParent = source.deletingLastPathComponent()

        guard sourceParent != destinationFolder else {
            throw SuperRightClickError.alreadyInDestination(source.lastPathComponent)
        }

        let destination = destinationFolder.appendingPathComponent(source.lastPathComponent)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw SuperRightClickError.destinationContainsItem(source.lastPathComponent)
        }

        let sourceValues = try source.resourceValues(forKeys: [.isDirectoryKey])
        if sourceValues.isDirectory == true {
            let sourceComponents = source.pathComponents
            let destinationComponents = destinationFolder.pathComponents
            if destinationComponents.starts(with: sourceComponents) {
                throw SuperRightClickError.cannotMoveIntoDescendant(source.lastPathComponent)
            }
        }
    }
}
