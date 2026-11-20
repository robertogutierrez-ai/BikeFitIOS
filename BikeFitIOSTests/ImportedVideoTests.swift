import Foundation
import XCTest
@testable import BikeFitIOS

final class ImportedVideoTests: XCTestCase {
    func testImportCopiesVideoWithoutChangingOriginal() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }
        let source = directory.appendingPathComponent("original.mp4")
        let contents = Data([1, 2, 3])
        try contents.write(to: source)

        let imported = try ImportedVideo.copyToTemporaryDirectory(source, directory: directory)
        XCTAssertNotEqual(imported, source)
        XCTAssertEqual(imported.pathExtension, "mp4")
        XCTAssertEqual(try Data(contentsOf: imported), contents)
        try FileManager.default.removeItem(at: imported)
        XCTAssertEqual(try Data(contentsOf: source), contents)
    }

    func testMissingVideoThrows() throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertThrowsError(try ImportedVideo.copyToTemporaryDirectory(source))
    }
}
