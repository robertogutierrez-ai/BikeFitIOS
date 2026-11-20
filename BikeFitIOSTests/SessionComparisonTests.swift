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
}
