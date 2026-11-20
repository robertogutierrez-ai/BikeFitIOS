import Foundation
import XCTest
@testable import BikeFitIOS

final class SensorDecoderTests: XCTestCase {
    func testDecodesPowerAndBothHeartRateFormats() throws {
        XCTAssertEqual(try SensorDecoder.power(Data([0, 0, 0x9c, 0xff])), -100)
        XCTAssertEqual(try SensorDecoder.heartRate(Data([0, 80])), 80)
        XCTAssertEqual(try SensorDecoder.heartRate(Data([1, 0x2c, 0x01])), 300)
        XCTAssertThrowsError(try SensorDecoder.power(Data([0, 0, 1])))
        XCTAssertThrowsError(try SensorDecoder.heartRate(Data([1, 0])))
    }

    func testDecodesCrankWithWheelAndHandlesCounterWrap() throws {
        let sample = try XCTUnwrap(SensorDecoder.crank(Data([3, 0, 0, 0, 0, 0, 0, 1, 0, 0, 2])))
        XCTAssertEqual(sample.revolutions, 1)
        XCTAssertEqual(sample.eventTime, 512)
        let previous = SensorDecoder.CrankSample(revolutions: 65535, eventTime: 65024)
        XCTAssertEqual(try XCTUnwrap(SensorDecoder.cadence(previous: previous, current: sample)), 120, accuracy: 0.001)
        XCTAssertNil(SensorDecoder.cadence(previous: sample, current: sample))
        XCTAssertNil(try SensorDecoder.crank(Data([0])))
        XCTAssertThrowsError(try SensorDecoder.crank(Data([3, 0, 0])))
    }
}
