import Foundation
import XCTest
@testable import BikeFitIOS

final class SessionHistoryStoreTests: XCTestCase {
    func testSaveLoadAndDeleteDoNotAffectOtherSession() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SessionHistoryStore(directory: directory)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }
        XCTAssertTrue(try store.load().isEmpty)

        let result = VideoAnalysisResult(
            ranges: [.knee: AngleRange(minimum: 10, maximum: 25)],
            validFrames: 5, sampledFrames: 8, side: "izquierdo",
            timeline: [AngleSample(time: 0.4, angles: [.knee: 10])],
            kops: KopsVideoResult(offsetMillimeters: 12, time: 0.4, validSamples: 4, facingRight: true)
        )
        let first = try store.save(result)
        let second = try store.save(result)
        let loaded = try store.load()
        XCTAssertEqual(loaded.count, 2)
        let restored = try XCTUnwrap(loaded.first { $0.id == first.id })
        XCTAssertEqual(restored.result.ranges[.knee]?.minimum, 10)
        XCTAssertEqual(restored.result.ranges[.knee]?.maximum, 25)
        XCTAssertEqual(restored.result.validFrames, 5)
        XCTAssertEqual(restored.result.sampledFrames, 8)
        XCTAssertEqual(restored.result.side, "izquierdo")
        XCTAssertEqual(restored.result.timeline?.first?.time, 0.4)
        XCTAssertEqual(restored.result.timeline?.first?.angles[.knee], 10)
        XCTAssertEqual(restored.result.kops?.offsetMillimeters, 12)
        XCTAssertEqual(restored.result.kops?.validSamples, 4)

        try store.delete(first)
        let remaining = try store.load()
        XCTAssertEqual(remaining.map(\.id), [second.id])
    }

    func testOlderResultWithoutTimelineRemainsReadable() throws {
        let data = Data("""
        {"ranges":[],"validFrames":1,"sampledFrames":2,"side":"izquierdo"}
        """.utf8)
        let result = try JSONDecoder().decode(VideoAnalysisResult.self, from: data)
        XCTAssertNil(result.timeline)
        XCTAssertNil(result.estimatedCycles)
        XCTAssertNil(result.engine)
        XCTAssertNil(result.kops)
        XCTAssertEqual(result.validFrames, 1)
    }

    func testCorruptSessionIsReported() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }
        try Data([0]).write(to: directory.appendingPathComponent("invalid.json"))
        XCTAssertThrowsError(try SessionHistoryStore(directory: directory).load())
    }
}
