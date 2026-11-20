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
        XCTAssertEqual(try XCTUnwrap(result[.backInclination]), 90, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(result[.thighInclination]), 0, accuracy: 0.001)
    }

    func testInclinationIsIndependentOfDirectionAndRejectsDegenerateLine() throws {
        let first = CGPoint(x: 0, y: 0)
        let second = CGPoint(x: 1, y: 1)
        XCTAssertEqual(try XCTUnwrap(AngleCalculator.inclination(first, second)), 45, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(AngleCalculator.inclination(second, first)), 45, accuracy: 0.001)
        XCTAssertNil(AngleCalculator.inclination(first, first))
    }

    func testFootAnglesRequireToeAndUseImageAspectRatio() throws {
        var points = BodyPoints(
            shoulder: CGPoint(x: 0, y: 0), elbow: CGPoint(x: 0.1, y: 0),
            wrist: CGPoint(x: 0.2, y: 0), hip: CGPoint(x: 0, y: 0.5),
            knee: CGPoint(x: 0.5, y: 1), ankle: CGPoint(x: 0.5, y: 0.5)
        )
        XCTAssertNil(AngleCalculator.calculate(points, width: 200, height: 100)[.ankle])
        points.foot = CGPoint(x: 0.75, y: 0)
        let angles = AngleCalculator.calculate(points, width: 200, height: 100)
        XCTAssertEqual(try XCTUnwrap(angles[.ankle]), 45, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(angles[.footInclination]), 45, accuracy: 0.001)
        points.foot = points.ankle
        XCTAssertNil(AngleCalculator.calculate(points, width: 200, height: 100)[.ankle])
        XCTAssertNil(AngleCalculator.calculate(points, width: 200, height: 100)[.footInclination])
    }

    func testDirectedTrunkDependsOnImageDirection() throws {
        let hip = CGPoint(x: 0, y: 0)
        XCTAssertEqual(try XCTUnwrap(AngleCalculator.directedTrunk(shoulder: CGPoint(x: 1, y: 1), hip: hip)), 45, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(AngleCalculator.directedTrunk(shoulder: CGPoint(x: -1, y: 1), hip: hip)), 135, accuracy: 0.001)
        XCTAssertNil(AngleCalculator.directedTrunk(shoulder: hip, hip: hip))
    }
}
