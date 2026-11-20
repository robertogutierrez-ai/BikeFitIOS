import XCTest
@testable import BikeFitIOS

final class LiveAnalysisCameraTests: XCTestCase {
    func testSelectsAvailableSideAndClearsWhenTrackingIsLost() {
        let angles: [JointAngle: Double] = [.knee: 45]
        XCTAssertEqual(LiveAnalysisCamera.preferredSide(in: [:]), nil)
        XCTAssertEqual(LiveAnalysisCamera.preferredSide(in: [.right: angles]), .right)
        XCTAssertEqual(LiveAnalysisCamera.preferredSide(in: [.left: angles]), .left)
        XCTAssertEqual(LiveAnalysisCamera.preferredSide(in: [.left: angles, .right: angles]), .left)
    }
}
