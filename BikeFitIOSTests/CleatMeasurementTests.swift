import XCTest
@testable import BikeFitIOS

final class CleatMeasurementTests: XCTestCase {
    func testAlignedAxesAndRelativeOffsets() throws {
        let result = try XCTUnwrap(CleatMeasurement.calculate(
            shoeFront: CGPoint(x: 0.5, y: 0.1),
            shoeHeel: CGPoint(x: 0.5, y: 0.9),
            cleatFront: CGPoint(x: 0.5, y: 0.3),
            cleatHeel: CGPoint(x: 0.5, y: 0.6)
        ))
        XCTAssertEqual(result.rotationDegrees, 0, accuracy: 0.001)
        XCTAssertEqual(result.lateralRelativeToShoe, 0, accuracy: 0.001)
        XCTAssertEqual(result.longitudinalRelativeToShoe, 0.0625, accuracy: 0.001)
    }

    func testRotationAndLateralOffset() throws {
        let result = try XCTUnwrap(CleatMeasurement.calculate(
            shoeFront: CGPoint(x: 0.5, y: 0.1),
            shoeHeel: CGPoint(x: 0.5, y: 0.9),
            cleatFront: CGPoint(x: 0.6, y: 0.3),
            cleatHeel: CGPoint(x: 0.5, y: 0.6)
        ))
        XCTAssertEqual(result.rotationDegrees, 18.435, accuracy: 0.01)
        XCTAssertEqual(result.lateralRelativeToShoe, 0.0625, accuracy: 0.001)
    }

    func testReversingCleatAxisDoesNotChangeRotation() throws {
        let result = try XCTUnwrap(CleatMeasurement.calculate(
            shoeFront: CGPoint(x: 0.5, y: 0.1),
            shoeHeel: CGPoint(x: 0.5, y: 0.9),
            cleatFront: CGPoint(x: 0.5, y: 0.6),
            cleatHeel: CGPoint(x: 0.6, y: 0.3)
        ))
        XCTAssertEqual(result.rotationDegrees, 18.435, accuracy: 0.01)
    }

    func testRejectsShortAndNonFiniteAxes() {
        let front = CGPoint(x: 0.5, y: 0.1)
        let heel = CGPoint(x: 0.5, y: 0.9)
        XCTAssertNil(CleatMeasurement.calculate(shoeFront: front, shoeHeel: front, cleatFront: front, cleatHeel: heel))
        XCTAssertNil(CleatMeasurement.calculate(shoeFront: front, shoeHeel: heel, cleatFront: front, cleatHeel: front))
        XCTAssertNil(CleatMeasurement.calculate(shoeFront: CGPoint(x: CGFloat.nan, y: 0), shoeHeel: heel, cleatFront: front, cleatHeel: heel))
    }
}
