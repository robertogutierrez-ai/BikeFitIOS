import XCTest
import CoreGraphics
@testable import BikeFitIOS

final class LiveAnalysisCameraTests: XCTestCase {
    func testSelectsAvailableSideAndClearsWhenTrackingIsLost() {
        let angles: [JointAngle: Double] = [.knee: 45]
        XCTAssertEqual(LiveAnalysisCamera.preferredSide(in: [:]), nil)
        XCTAssertEqual(LiveAnalysisCamera.preferredSide(in: [.right: angles]), .right)
        XCTAssertEqual(LiveAnalysisCamera.preferredSide(in: [.left: angles]), .left)
        XCTAssertEqual(LiveAnalysisCamera.preferredSide(in: [.left: angles, .right: angles]), .left)
    }

    func testFrontalSeparationIsUndirectedAndRequiresValidCoordinates() throws {
        let knee = CGPoint(x: 0.3, y: 0.6)
        let ankle = CGPoint(x: 0.4, y: 0.2)
        XCTAssertEqual(try XCTUnwrap(FrontalKneeMeasurement.separation(knee: knee, ankle: ankle)), 10, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(FrontalKneeMeasurement.separation(knee: ankle, ankle: knee)), 10, accuracy: 0.001)
        XCTAssertNil(FrontalKneeMeasurement.separation(knee: CGPoint(x: -0.1, y: 0.2), ankle: ankle))
        XCTAssertNil(FrontalKneeMeasurement.separation(knee: CGPoint(x: CGFloat.nan, y: 0.2), ankle: ankle))
    }
}
