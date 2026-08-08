import Darwin
import Foundation

enum FinderMenuAction: String, CaseIterable, Hashable {
    case copyPath
    case moveTo
    case hideSelected
    case unhideFolderContents
    case openInTerminal
}

enum FinderMenuSettings {
    private static let lock = NSLock()

    static var settingsURL: URL {
        currentUserHomeDirectory
            .appendingPathComponent("Library/Application Support/RightClickPai", isDirectory: true)
            .appendingPathComponent("FinderMenuSettings.plist", isDirectory: false)
    }

    static func hasStoredSettings(at url: URL = settingsURL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    static func isEnabled(
        _ action: FinderMenuAction,
        at url: URL = settingsURL
    ) -> Bool {
        lock.withLock {
            (try? load(from: url)[action.rawValue]) ?? true
        }
    }

    static func enabledStates(
        at url: URL = settingsURL
    ) -> [FinderMenuAction: Bool] {
        lock.withLock {
            let stored = (try? load(from: url)) ?? [:]
            return Dictionary(uniqueKeysWithValues: FinderMenuAction.allCases.map {
                ($0, stored[$0.rawValue] ?? true)
            })
        }
    }

    static func setEnabled(
        _ enabled: Bool,
        for action: FinderMenuAction,
        at url: URL = settingsURL
    ) throws {
        try lock.withLock {
            var stored = try load(from: url)
            stored[action.rawValue] = enabled
            try save(stored, to: url)
        }
    }

    static func saveInitialStates(
        _ states: [FinderMenuAction: Bool],
        at url: URL = settingsURL
    ) throws {
        try lock.withLock {
            guard !FileManager.default.fileExists(atPath: url.path) else { return }
            let stored = Dictionary(uniqueKeysWithValues: FinderMenuAction.allCases.map {
                ($0.rawValue, states[$0] ?? true)
            })
            try save(stored, to: url)
        }
    }

    private static func load(from url: URL) throws -> [String: Bool] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        let propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)
        return propertyList as? [String: Bool] ?? [:]
    }

    private static func save(_ settings: [String: Bool], to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try PropertyListSerialization.data(
            fromPropertyList: settings,
            format: .binary,
            options: 0
        )
        try data.write(to: url, options: .atomic)
    }

    private static var currentUserHomeDirectory: URL {
        if let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: directory), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
