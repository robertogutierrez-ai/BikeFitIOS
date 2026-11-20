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
                                               knee: CGPoint(x: .nan, y: 0), pedal: end, referenceMillimeters: 100))
    }
}
