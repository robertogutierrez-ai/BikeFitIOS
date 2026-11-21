import XCTest
@testable import BikeFitIOS

final class LiveSessionAccumulatorTests: XCTestCase {
    func testSessionSelectsOneSideAndSmoothsWithoutMixingSides() throws {
        var session = LiveSessionAccumulator()
        try session.add(time: 10, measured: [.left: [.knee: 100], .right: [.knee: 40]])
        try session.add(time: 10.2, measured: [.left: [.knee: 60]])
        try session.add(time: 10.4, measured: [:])
        let result = try session.result()
        XCTAssertEqual(result.engine, .vision)
        XCTAssertEqual(result.side, "izquierdo")
        XCTAssertEqual(result.sampledFrames, 3)
        XCTAssertEqual(result.validFrames, 2)
        XCTAssertEqual(result.estimatedCycles, 1)
        XCTAssertEqual(try XCTUnwrap(result.timeline?.last?.angles[.knee]), 80, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(result.timeline?.last?.time), 0.2, accuracy: 0.001)
    }

    func testMissingAndOldFramesDoNotLeakIntoNewMeasurements() throws {
        var session = LiveSessionAccumulator()
        XCTAssertThrowsError(try session.result())
        try session.add(time: 1, measured: [.left: [.knee: 100, .ankle: 30]])
        try session.add(time: 3, measured: [.left: [.knee: 60]])
        let result = try session.result()
        XCTAssertEqual(result.estimatedCycles, 0)
        XCTAssertEqual(result.timeline?.last?.angles[.knee], 60)
        XCTAssertNil(result.timeline?.last?.angles[.ankle])
        XCTAssertThrowsError(try session.add(time: 3, measured: [:]))
    }

    func testLostTrackingResetsSmoothingWindow() throws {
        var session = LiveSessionAccumulator()
        try session.add(time: 1, measured: [.left: [.knee: 100]])
        try session.add(time: 1.2, measured: [:])
        try session.add(time: 1.4, measured: [.left: [.knee: 60]])
        XCTAssertEqual(session.latest(for: .left)?[.knee], 60)
    }

    func testMovementIsPerSideAndDoesNotFilterSessionSamples() throws {
        var session = LiveSessionAccumulator()
        try session.add(time: 0, measured: [.left: [.knee: 40], .right: [.knee: 50]])
        try session.add(time: 0.2, measured: [.left: [.knee: 80], .right: [.knee: 50]])
        try session.add(time: 0.5, measured: [.left: [.knee: 100], .right: [.knee: 50]])
        XCTAssertTrue(session.isPedaling(for: .left))
        XCTAssertFalse(session.isPedaling(for: .right))
        XCTAssertEqual(try session.result().validFrames, 3)
        try session.add(time: 0.7, measured: [.right: [.knee: 50]])
        XCTAssertFalse(session.isPedaling(for: .left))
        try session.add(time: 0.9, measured: [.left: [.knee: 100]])
        XCTAssertFalse(session.isPedaling(for: .left))
        XCTAssertEqual(try session.result().sampledFrames, 5)
        XCTAssertEqual(try session.result().validFrames, 4)
    }

    func testSessionStoresChosenEngineAndFootMeasurements() throws {
        var session = LiveSessionAccumulator(engine: .mediaPipe)
        try session.add(time: 1, measured: [.right: [.knee: 50, .ankle: 30]])
        let result = try session.result()
        XCTAssertEqual(result.engine, .mediaPipe)
        XCTAssertEqual(result.ranges[.ankle]?.minimum, 30)
        XCTAssertEqual(result.timeline?.first?.angles[.ankle], 30)
    }
}
