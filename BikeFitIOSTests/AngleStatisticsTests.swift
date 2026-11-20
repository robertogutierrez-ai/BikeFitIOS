import Foundation
import XCTest
@testable import BikeFitIOS

final class AngleStatisticsTests: XCTestCase {
    func testStatisticsUseOnlyAvailableMeasurements() throws {
        let samples = [
            AngleSample(time: 0, angles: [.knee: 10]),
            AngleSample(time: 0.2, angles: [.knee: 20]),
            AngleSample(time: 0.4, angles: [.hip: 50]),
            AngleSample(time: 0.6, angles: [.knee: 30])
        ]
        let stats = try XCTUnwrap(AngleStatistics.calculate(for: .knee, samples: samples))
        XCTAssertEqual(stats.count, 3)
        XCTAssertEqual(stats.mean, 20, accuracy: 0.0001)
        XCTAssertEqual(stats.standardDeviation, sqrt(200.0 / 3), accuracy: 0.0001)
        XCTAssertEqual(stats.amplitude, 20, accuracy: 0.0001)
        XCTAssertNil(AngleStatistics.calculate(for: .elbow, samples: samples))
    }

    func testSingleMeasurementHasNoVariationOrAmplitude() throws {
        let stats = try XCTUnwrap(AngleStatistics.calculate(
            for: .knee, samples: [AngleSample(time: 0, angles: [.knee: 42])]
        ))
        XCTAssertEqual(stats.standardDeviation, 0)
        XCTAssertEqual(stats.amplitude, 0)
    }
}
