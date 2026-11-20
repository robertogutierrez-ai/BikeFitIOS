import CoreGraphics
import XCTest
@testable import BikeFitIOS

final class PedalingPhasesTests: XCTestCase {
    func testExtremaRequireCycleAndMovementAndSpreadUsesImageWidth() throws {
        var tracker = PedalingPhases()
        func points(ankleY: CGFloat, kneeX: CGFloat) -> BodyPoints {
            let p = CGPoint(x: 0.5, y: 0.5)
            return BodyPoints(shoulder: p, elbow: p, wrist: p, hip: p,
                              knee: CGPoint(x: kneeX, y: 0.5), ankle: CGPoint(x: 0.5, y: ankleY))
        }
        tracker.add(points: points(ankleY: 0.8, kneeX: 0.4), time: 0.2)
        tracker.add(points: points(ankleY: 0.2, kneeX: 0.6), time: 0.4)
        XCTAssertTrue(tracker.phases(cycles: 0).isEmpty)
        XCTAssertEqual(tracker.phases(cycles: 1).map(\.time), [0.2, 0.4])
        XCTAssertEqual(tracker.phases(cycles: 1, calibratedFacingRight: true).map(\.kind),
                       [.top, .bottom, .forward])
        XCTAssertEqual(try XCTUnwrap(tracker.kneeHorizontalSpreadPercent), 10, accuracy: 0.001)
        var staticTracker = PedalingPhases()
        staticTracker.add(points: points(ankleY: 0.5, kneeX: 0.5), time: 0)
        XCTAssertTrue(staticTracker.phases(cycles: 1).isEmpty)
        XCTAssertNil(staticTracker.kneeHorizontalSpreadPercent)
    }

    func testDirectionRequiresAgreementAndCalibrationOverridesInference() {
        func points(ankleX: CGFloat, ankleY: CGFloat, kneeX: CGFloat) -> BodyPoints {
            let p = CGPoint(x: 0.5, y: 0.5)
            return BodyPoints(shoulder: p, elbow: p, wrist: p, hip: p,
                              knee: CGPoint(x: kneeX, y: 0.5),
                              ankle: CGPoint(x: ankleX, y: ankleY))
        }
        var tracker = PedalingPhases()
        tracker.add(points: points(ankleX: 0.2, ankleY: 0.8, kneeX: 0.6), time: 0)
        tracker.add(points: points(ankleX: 0.8, ankleY: 0.2, kneeX: 0.6), time: 0.2)
        XCTAssertEqual(tracker.phases(cycles: 1).count, 2)
        tracker.add(points: points(ankleX: 0.5, ankleY: 0.5, kneeX: 0.6), time: 0.4)
        XCTAssertEqual(tracker.phases(cycles: 1).last?.time, 0.2)
        XCTAssertEqual(tracker.phases(cycles: 1, calibratedFacingRight: false).last?.time, 0)
        tracker.add(points: points(ankleX: 0.5, ankleY: 0.5, kneeX: 0.4), time: 0.6)
        XCTAssertEqual(tracker.phases(cycles: 1).count, 2)
    }
}
