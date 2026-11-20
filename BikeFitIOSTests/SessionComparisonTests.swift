import XCTest
@testable import BikeFitIOS

final class SessionComparisonTests: XCTestCase {
    func testComparesEachEndpointAndIgnoresMissingMetrics() throws {
        let baseline = VideoAnalysisResult(
            ranges: [.knee: AngleRange(minimum: 10, maximum: 50)],
            validFrames: 5, sampledFrames: 8, side: "izquierdo"
        )
        let comparison = VideoAnalysisResult(
            ranges: [.knee: AngleRange(minimum: 15, maximum: 45), .hip: AngleRange(minimum: 1, maximum: 2)],
            validFrames: 4, sampledFrames: 8, side: "derecho"
        )
        let change = try XCTUnwrap(SessionComparison.difference(for: .knee, baseline: baseline, comparison: comparison))
        XCTAssertEqual(change.minimum, 5)
        XCTAssertEqual(change.maximum, -5)
        XCTAssertNil(SessionComparison.difference(for: .hip, baseline: baseline, comparison: comparison))
    }

    func testSpecialModesRequireCompatibleSidesAndEngines() {
        let left = VideoAnalysisResult(ranges: [:], validFrames: 1, sampledFrames: 1, side: "izquierdo")
        let right = VideoAnalysisResult(ranges: [:], validFrames: 1, sampledFrames: 1, side: "derecho", engine: .vision)
        let mediaPipe = VideoAnalysisResult(ranges: [:], validFrames: 1, sampledFrames: 1, side: "derecho", engine: .mediaPipe)
        let unknown = VideoAnalysisResult(ranges: [:], validFrames: 1, sampledFrames: 1, side: "desconocido")

        XCTAssertNil(SessionComparison.unavailableReason(mode: .beforeAfter, baseline: left, comparison: left))
        XCTAssertNotNil(SessionComparison.unavailableReason(mode: .beforeAfter, baseline: left, comparison: right))
        XCTAssertNil(SessionComparison.unavailableReason(mode: .bilateral, baseline: left, comparison: right))
        XCTAssertNotNil(SessionComparison.unavailableReason(mode: .bilateral, baseline: left, comparison: left))
        XCTAssertNotNil(SessionComparison.unavailableReason(mode: .bilateral, baseline: left, comparison: mediaPipe))
        XCTAssertNotNil(SessionComparison.unavailableReason(mode: .bilateral, baseline: left, comparison: unknown))
        XCTAssertNil(SessionComparison.unavailableReason(mode: .general, baseline: left, comparison: mediaPipe))
    }

    func testMeanDifferenceUsesAvailableSamplesAndSupportsOlderSessions() throws {
        let first = VideoAnalysisResult(ranges: [:], validFrames: 2, sampledFrames: 2, side: "izquierdo",
                                        timeline: [
                                            AngleSample(time: 0, angles: [.knee: 10]),
                                            AngleSample(time: 1, angles: [.knee: 30])
                                        ])
        let second = VideoAnalysisResult(ranges: [:], validFrames: 2, sampledFrames: 2, side: "izquierdo",
                                         timeline: [
                                            AngleSample(time: 0, angles: [.knee: 25]),
                                            AngleSample(time: 1, angles: [.hip: 10])
                                         ])
        let difference = try XCTUnwrap(SessionComparison.meanDifference(for: .knee, baseline: first, comparison: second))
        XCTAssertEqual(difference.value, 5, accuracy: 0.001)
        XCTAssertEqual(difference.baselineCount, 2)
        XCTAssertEqual(difference.comparisonCount, 1)
        XCTAssertNil(SessionComparison.meanDifference(for: .hip, baseline: first, comparison: second))
        var old = second
        old.timeline = nil
        XCTAssertNil(SessionComparison.meanDifference(for: .knee, baseline: first, comparison: old))
    }
}
