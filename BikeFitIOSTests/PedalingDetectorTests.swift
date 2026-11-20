import XCTest
@testable import BikeFitIOS

final class PedalingDetectorTests: XCTestCase {
    func testCountsFlexedToExtendedTransitions() throws {
        var detector = PedalingDetector()
        for (time, angle) in [(0.0, 80.0), (0.2, 120.0), (0.4, 80.0), (0.6, 120.0)] {
            try detector.add(kneeAngle: angle, time: time)
        }
        XCTAssertEqual(detector.cycles, 2)
    }

    func testDoesNotCountAcrossLongTrackingGap() throws {
        var detector = PedalingDetector()
        try detector.add(kneeAngle: 80, time: 0)
        try detector.add(kneeAngle: 120, time: 2)
        XCTAssertEqual(detector.cycles, 0)
    }

    func testRejectsOutOfOrderAndShortPhaseChanges() throws {
        var detector = PedalingDetector()
        try detector.add(kneeAngle: 80, time: 0)
        try detector.add(kneeAngle: 120, time: 0.05)
        XCTAssertThrowsError(try detector.add(kneeAngle: 120, time: 0))
        XCTAssertEqual(detector.cycles, 0)
        try detector.add(kneeAngle: 120, time: 0.2)
        XCTAssertEqual(detector.cycles, 1)
    }
}
