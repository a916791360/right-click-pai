import Foundation
import XCTest

final class FileOperationsTests: XCTestCase {
    func testPathTextUsesPlainAbsolutePathsSeparatedByNewlines() {
        let urls = [
            URL(fileURLWithPath: "/Users/test/My Files/report.pdf"),
            URL(fileURLWithPath: "/Users/test/中文.txt")
        ]

        XCTAssertEqual(
            PathTextFormatter.text(for: urls),
            "/Users/test/My Files/report.pdf\n/Users/test/中文.txt"
        )
    }

    func testActionInputLoaderAcceptsPlainTextPathsAndFileURLs() {
        let path = "/Users/test/My Files/report.pdf"

        XCTAssertEqual(ActionInputLoader.url(from: path as NSString)?.path, path)
        XCTAssertEqual(
            ActionInputLoader.url(from: "file:///Users/test/My%20Files/report.pdf" as NSString)?.path,
            path
        )
        XCTAssertEqual(ActionInputLoader.url(from: Data(path.utf8) as NSData)?.path, path)
    }

    func testActionInputLoaderLoadsDocumentProviderInPlace() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let document = root.appendingPathComponent("report.docx")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        XCTAssertTrue(FileManager.default.createFile(atPath: document.path, contents: Data()))
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = NSItemProvider()
        provider.registerFileRepresentation(
            forTypeIdentifier: "org.openxmlformats.wordprocessingml.document",
            fileOptions: [.openInPlace],
            visibility: .all
        ) { completion in
            completion(document, true, nil)
            return nil
        }

        let loaded = expectation(description: "Loads the original document URL")
        ActionInputLoader.loadURLs(from: [provider]) { result in
            do {
                let scopedURLs = try result.get()
                XCTAssertEqual(scopedURLs.urls, [document])
                _ = scopedURLs
            } catch {
                XCTFail("Unexpected loading error: \(error)")
            }
            loaded.fulfill()
        }

        wait(for: [loaded], timeout: 2)
    }

    func testUnhideOnlyAffectsDirectNonDotChildren() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let child = root.appendingPathComponent("child.txt")
        let dotFile = root.appendingPathComponent(".metadata")
        let nestedFolder = root.appendingPathComponent("nested", isDirectory: true)
        let nestedChild = nestedFolder.appendingPathComponent("nested.txt")

        try FileManager.default.createDirectory(at: nestedFolder, withIntermediateDirectories: true)
        XCTAssertTrue(FileManager.default.createFile(atPath: child.path, contents: Data()))
        XCTAssertTrue(FileManager.default.createFile(atPath: dotFile.path, contents: Data()))
        XCTAssertTrue(FileManager.default.createFile(atPath: nestedChild.path, contents: Data()))
        defer { try? FileManager.default.removeItem(at: root) }

        try FinderFileOperations.hide([child, nestedChild])
        try FinderFileOperations.unhideDirectChildren(of: [root])

        XCTAssertEqual(try child.resourceValues(forKeys: [.isHiddenKey]).isHidden, false)
        XCTAssertEqual(try nestedChild.resourceValues(forKeys: [.isHiddenKey]).isHidden, true)
        XCTAssertEqual(try dotFile.resourceValues(forKeys: [.isHiddenKey]).isHidden, true)
    }

    func testMovePlacesSelectedItemsInDestination() throws {
        let root = try makeTemporaryDirectory()
        let sourceFolder = root.appendingPathComponent("source", isDirectory: true)
        let destinationFolder = root.appendingPathComponent("destination", isDirectory: true)
        let document = sourceFolder.appendingPathComponent("report.txt")
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        XCTAssertTrue(FileManager.default.createFile(atPath: document.path, contents: Data("content".utf8)))
        defer { try? FileManager.default.removeItem(at: root) }

        try FinderFileOperations.move([document], to: destinationFolder)

        XCTAssertFalse(FileManager.default.fileExists(atPath: document.path))
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: destinationFolder.appendingPathComponent("report.txt").path
            )
        )
    }

    func testMoveDoesNotOverwriteExistingItem() throws {
        let root = try makeTemporaryDirectory()
        let sourceFolder = root.appendingPathComponent("source", isDirectory: true)
        let destinationFolder = root.appendingPathComponent("destination", isDirectory: true)
        let source = sourceFolder.appendingPathComponent("report.txt")
        let existing = destinationFolder.appendingPathComponent("report.txt")
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        XCTAssertTrue(FileManager.default.createFile(atPath: source.path, contents: Data("source".utf8)))
        XCTAssertTrue(FileManager.default.createFile(atPath: existing.path, contents: Data("existing".utf8)))
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(try FinderFileOperations.move([source], to: destinationFolder))
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "source")
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "existing")
    }

    func testMoveRejectsMovingFolderIntoItsDescendant() throws {
        let root = try makeTemporaryDirectory()
        let sourceFolder = root.appendingPathComponent("source", isDirectory: true)
        let nestedFolder = sourceFolder.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(try FinderFileOperations.move([sourceFolder], to: nestedFolder))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFolder.path))
    }

    func testFinderMenuSettingsDefaultToEnabledAndPersistIndependently() throws {
        let root = try makeTemporaryDirectory()
        let settingsURL = root.appendingPathComponent("settings.plist")
        defer { try? FileManager.default.removeItem(at: root) }

        for action in FinderMenuAction.allCases {
            XCTAssertTrue(FinderMenuSettings.isEnabled(action, at: settingsURL))
        }

        try FinderMenuSettings.setEnabled(false, for: .moveTo, at: settingsURL)

        XCTAssertFalse(FinderMenuSettings.isEnabled(.moveTo, at: settingsURL))
        XCTAssertTrue(FinderMenuSettings.isEnabled(.copyPath, at: settingsURL))
        XCTAssertTrue(FinderMenuSettings.isEnabled(.hideSelected, at: settingsURL))
        XCTAssertTrue(FinderMenuSettings.isEnabled(.unhideFolderContents, at: settingsURL))
    }

    func testMoveRequestRoundTripsPathsAndCanOnlyBeConsumedOnce() throws {
        let root = try makeTemporaryDirectory()
        let urls = [
            URL(fileURLWithPath: "/Users/test/My Files/report.pdf"),
            URL(fileURLWithPath: "/Volumes/USB/资料.txt")
        ]
        defer { try? FileManager.default.removeItem(at: root) }

        let identifier = try MoveRequestStore.create(for: urls, rootDirectory: root)

        XCTAssertEqual(
            MoveRequestStore.identifier(from: MoveRequestStore.deepLink(for: identifier)),
            identifier
        )
        XCTAssertEqual(try MoveRequestStore.consume(identifier, rootDirectory: root), urls)
        XCTAssertThrowsError(try MoveRequestStore.consume(identifier, rootDirectory: root))
    }

    func testTerminalRequestRoundTripsPathsAndCanOnlyBeConsumedOnce() throws {
        let root = try makeTemporaryDirectory()
        let urls = [
            URL(fileURLWithPath: "/Users/test/Projects/right-click-pai"),
            URL(fileURLWithPath: "/Users/test/Projects/README.md")
        ]
        defer { try? FileManager.default.removeItem(at: root) }

        let identifier = try TerminalRequestStore.create(for: urls, rootDirectory: root)

        XCTAssertEqual(
            TerminalRequestStore.identifier(from: TerminalRequestStore.deepLink(for: identifier)),
            identifier
        )
        XCTAssertEqual(try TerminalRequestStore.consume(identifier, rootDirectory: root), urls)
        XCTAssertThrowsError(try TerminalRequestStore.consume(identifier, rootDirectory: root))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
