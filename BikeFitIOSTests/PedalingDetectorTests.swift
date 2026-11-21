import XCTest
@testable import BikeFitIOS

final class PedalingDetectorTests: XCTestCase {
    func testCountsFlexedToExtendedTransitions() throws {
        var detector = PedalingDetector()
        for (time, angle) in [(0.0, 100.0), (0.2, 60.0), (0.4, 100.0), (0.6, 60.0)] {
            try detector.add(kneeAngle: angle, time: time)
        }
        XCTAssertEqual(detector.cycles, 2)
    }

    func testDoesNotCountAcrossLongTrackingGap() throws {
        var detector = PedalingDetector()
        try detector.add(kneeAngle: 100, time: 0)
        try detector.add(kneeAngle: 60, time: 2)
        XCTAssertEqual(detector.cycles, 0)
    }

    func testRejectsOutOfOrderAndShortPhaseChanges() throws {
        var detector = PedalingDetector()
        try detector.add(kneeAngle: 100, time: 0)
        try detector.add(kneeAngle: 60, time: 0.05)
        XCTAssertThrowsError(try detector.add(kneeAngle: 60, time: 0))
        XCTAssertEqual(detector.cycles, 0)
        try detector.add(kneeAngle: 60, time: 0.2)
        XCTAssertEqual(detector.cycles, 1)
    }

    func testStartingExtendedDoesNotCountUntilFlexionThenExtension() throws {
        var detector = PedalingDetector()
        try detector.add(kneeAngle: 30, time: 0)
        try detector.add(kneeAngle: 100, time: 0.2)
        XCTAssertEqual(detector.cycles, 0)
        try detector.add(kneeAngle: 30, time: 0.4)
        XCTAssertEqual(detector.cycles, 1)
    }

    func testMotionRequiresDurationAndKneeRangeAndExpires() {
        var motion = PedalingMotion()
        motion.add(kneeAngle: 50, time: 0)
        motion.add(kneeAngle: 55, time: 0.2)
        motion.add(kneeAngle: 59.9, time: 0.4)
        XCTAssertFalse(motion.detected)
        motion.add(kneeAngle: 60, time: 0.6)
        XCTAssertTrue(motion.detected)
        motion.add(kneeAngle: 60, time: 2.2)
        XCTAssertFalse(motion.detected)
    }

    func testMotionRequiresAtLeastThreeSamplesAndResets() {
        var motion = PedalingMotion()
        motion.add(kneeAngle: 50, time: 0)
        motion.add(kneeAngle: 70, time: 0.4)
        XCTAssertFalse(motion.detected)
        motion.add(kneeAngle: 70, time: 0.6)
        XCTAssertTrue(motion.detected)
        motion.reset()
        motion.add(kneeAngle: 70, time: 0.8)
        XCTAssertFalse(motion.detected)
    }
}
