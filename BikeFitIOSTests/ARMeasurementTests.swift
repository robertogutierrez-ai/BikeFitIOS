import XCTest
@testable import BikeFitIOS

final class ARMeasurementTests: XCTestCase {
    func testDistanceUsesThreeDimensionsAndRejectsInvalidPoints() throws {
        XCTAssertEqual(try XCTUnwrap(ARMeasurementMath.millimeters(
            from: SIMD3<Float>(0, 0, 0), to: SIMD3<Float>(0.3, 0.4, 0)
        )), 500, accuracy: 0.01)
        XCTAssertNil(ARMeasurementMath.millimeters(from: SIMD3<Float>(0, 0, 0), to: SIMD3<Float>(0, 0, 0)))
        XCTAssertNil(ARMeasurementMath.millimeters(
            from: SIMD3<Float>(Float.nan, 0, 0), to: SIMD3<Float>(0, 0, 1)
        ))
    }
}
