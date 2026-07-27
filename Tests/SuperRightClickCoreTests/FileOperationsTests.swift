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
}
