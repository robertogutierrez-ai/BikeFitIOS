import CoreGraphics
import XCTest
@testable import BikeFitIOS

final class KopsMeasurementTests: XCTestCase {
    func testUsesReferenceLengthAndSignedHorizontalDistance() throws {
        let value = try XCTUnwrap(KopsMeasurement.calculate(
            referenceStart: CGPoint(x: 0.1, y: 0.1), referenceEnd: CGPoint(x: 0.4, y: 0.5),
            knee: CGPoint(x: 0.6, y: 0.3), pedal: CGPoint(x: 0.4, y: 0.8),
            referenceMillimeters: 100
        ))
        XCTAssertEqual(value.offsetMillimeters, 40, accuracy: 0.001)
        let reversed = try XCTUnwrap(KopsMeasurement.calculate(
            referenceStart: CGPoint(x: 0.4, y: 0.5), referenceEnd: CGPoint(x: 0.1, y: 0.1),
            knee: CGPoint(x: 0.4, y: 0.8), pedal: CGPoint(x: 0.6, y: 0.3),
            referenceMillimeters: 100
        ))
        XCTAssertEqual(reversed.offsetMillimeters, -40, accuracy: 0.001)
    }

    func testRejectsInvalidLengthAndReference() {
        let point = CGPoint(x: 0.2, y: 0.2)
        let end = CGPoint(x: 0.4, y: 0.2)
        XCTAssertNil(KopsMeasurement.calculate(referenceStart: point, referenceEnd: point,
                                               knee: point, pedal: end, referenceMillimeters: 100))
        XCTAssertNil(KopsMeasurement.calculate(referenceStart: point, referenceEnd: end,
                                               knee: point, pedal: end, referenceMillimeters: 0))
        XCTAssertNil(KopsMeasurement.calculate(referenceStart: point, referenceEnd: end,
                                               knee: CGPoint(x: CGFloat.nan, y: 0), pedal: end, referenceMillimeters: 100))
    }

    func testVideoTrackerUsesForwardAnkleAndEstimatedPedal() throws {
        func pose(knee: CGFloat, ankle: CGFloat, foot: CGFloat?) -> BodyPoints {
            BodyPoints(shoulder: .zero, elbow: .zero, wrist: .zero, hip: .zero,
                       knee: CGPoint(x: knee, y: 0), ankle: CGPoint(x: ankle, y: 0),
                       foot: foot.map { CGPoint(x: $0, y: 0) })
        }
        var right = KopsVideoTracker(calibration: KopsCalibration(millimetersPerImageWidth: 1000, facingRight: true))
        right.add(points: pose(knee: 0.6, ankle: 0.4, foot: 0.5), time: 0)
        right.add(points: pose(knee: 0.8, ankle: 0.6, foot: 0.8), time: 1)
        right.add(points: pose(knee: 0.9, ankle: 0.9, foot: nil), time: 2)
        XCTAssertEqual(try XCTUnwrap(right.result.offsetMillimeters), 100, accuracy: 0.001)
        XCTAssertEqual(right.result.time, 1)
        XCTAssertEqual(right.result.validSamples, 2)

        var left = KopsVideoTracker(calibration: KopsCalibration(millimetersPerImageWidth: 1000, facingRight: false))
        left.add(points: pose(knee: 0.4, ankle: 0.6, foot: 0.5), time: 0)
        left.add(points: pose(knee: 0.2, ankle: 0.4, foot: 0.2), time: 1)
        XCTAssertEqual(try XCTUnwrap(left.result.offsetMillimeters), 100, accuracy: 0.001)
        XCTAssertEqual(left.result.time, 1)
    }

    func testVideoTrackerReturnsUnavailableWithoutToe() {
        let points = BodyPoints(shoulder: .zero, elbow: .zero, wrist: .zero, hip: .zero,
                                knee: .zero, ankle: .zero)
        var tracker = KopsVideoTracker(calibration: KopsCalibration(millimetersPerImageWidth: 1000, facingRight: true))
        tracker.add(points: points, time: 0)
        XCTAssertNil(tracker.result.offsetMillimeters)
        XCTAssertNil(tracker.result.time)
        XCTAssertEqual(tracker.result.validSamples, 0)
    }

    func testAnalysisRejectsCalibrationWithWrongEngineOrInvalidScale() {
        let url = URL(fileURLWithPath: "unused")
        let calibration = KopsCalibration(millimetersPerImageWidth: 1000, facingRight: true)
        XCTAssertThrowsError(try VideoAnalyzer.analyze(url: url, engine: .vision, kopsCalibration: calibration) { _ in })
        let invalid = KopsCalibration(millimetersPerImageWidth: .infinity, facingRight: true)
        XCTAssertThrowsError(try VideoAnalyzer.analyze(url: url, engine: .mediaPipe, kopsCalibration: invalid) { _ in })
    }
}
