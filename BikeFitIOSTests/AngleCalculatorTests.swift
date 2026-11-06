import XCTest
@testable import BikeFitIOS

final class AngleCalculatorTests: XCTestCase {
    func testRightAngle() throws {
        let value = try XCTUnwrap(AngleCalculator.angle(
            CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 1)
        ))
        XCTAssertEqual(value, 90, accuracy: 0.001)
    }

    func testStraightLineMatchesAndroidConvention() throws {
        let value = try XCTUnwrap(AngleCalculator.angle(
            CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 2, y: 0)
        ))
        XCTAssertEqual(value, 0, accuracy: 0.001)
    }

    func testDegenerateSegmentIsNotMeasured() {
        XCTAssertNil(AngleCalculator.angle(
            CGPoint(x: 1, y: 1), CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 2)
        ))
    }

    func testCoordinatesAreScaledToImageAspectRatio() throws {
        let points = BodyPoints(
            shoulder: CGPoint(x: 0, y: 0),
            elbow: CGPoint(x: 0.5, y: 0),
            wrist: CGPoint(x: 1, y: 0),
            hip: CGPoint(x: 0, y: 0.5),
            knee: CGPoint(x: 0.5, y: 0.5),
            ankle: CGPoint(x: 0.5, y: 1)
        )
        let result = AngleCalculator.calculate(points, width: 1920, height: 1080)
        XCTAssertEqual(try XCTUnwrap(result[.knee]), 90, accuracy: 0.001)
    }
}
