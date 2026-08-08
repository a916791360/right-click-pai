import Darwin
import Foundation

enum MoveRequestStore {
    static func create(
        for urls: [URL],
        rootDirectory: URL = requestsDirectory
    ) throws -> UUID {
        guard !urls.isEmpty else { throw SuperRightClickError.noInput }
        let identifier = UUID()
        let requestURL = url(for: identifier, rootDirectory: rootDirectory)
        try FileManager.default.createDirectory(
            at: requestURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try PropertyListSerialization.data(
            fromPropertyList: urls.map(\.path),
            format: .binary,
            options: 0
        )
        try data.write(to: requestURL, options: .atomic)
        return identifier
    }

    static func consume(
        _ identifier: UUID,
        rootDirectory: URL = requestsDirectory
    ) throws -> [URL] {
        let requestURL = url(for: identifier, rootDirectory: rootDirectory)
        let data = try Data(contentsOf: requestURL)
        try? FileManager.default.removeItem(at: requestURL)
        guard
            let paths = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String],
            !paths.isEmpty
        else {
            throw SuperRightClickError.unsupportedInput
        }
        return paths.map { URL(fileURLWithPath: $0) }
    }

    static func discard(
        _ identifier: UUID,
        rootDirectory: URL = requestsDirectory
    ) {
        try? FileManager.default.removeItem(
            at: url(for: identifier, rootDirectory: rootDirectory)
        )
    }

    static func deepLink(for identifier: UUID) -> URL {
        URL(string: "rightclickpai://move/\(identifier.uuidString)")!
    }

    static func identifier(from url: URL) -> UUID? {
        guard url.scheme == "rightclickpai", url.host == "move" else { return nil }
        let value = url.pathComponents.last(where: { $0 != "/" })
        return value.flatMap(UUID.init(uuidString:))
    }

    static func url(
        for identifier: UUID,
        rootDirectory: URL = requestsDirectory
    ) -> URL {
        rootDirectory.appendingPathComponent("\(identifier.uuidString).plist", isDirectory: false)
    }

    static var requestsDirectory: URL {
        currentUserHomeDirectory
            .appendingPathComponent("Library/Application Support/RightClickPai", isDirectory: true)
            .appendingPathComponent("MoveRequests", isDirectory: true)
    }

    private static var currentUserHomeDirectory: URL {
        if let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: directory), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }
}
