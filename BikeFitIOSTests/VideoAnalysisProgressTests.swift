import XCTest
@testable import BikeFitIOS

final class VideoAnalysisProgressTests: XCTestCase {
    func testProgressReflectsProcessedTimeAndCapsAtCompletion() {
        XCTAssertEqual(VideoAnalyzer.progress(after: 0, duration: 1), 0.2, accuracy: 0.0001)
        XCTAssertEqual(VideoAnalyzer.progress(after: 0.4, duration: 1), 0.6, accuracy: 0.0001)
        XCTAssertEqual(VideoAnalyzer.progress(after: 0, duration: 0.1), 1, accuracy: 0.0001)
        XCTAssertEqual(VideoAnalyzer.progress(after: 0.8, duration: 1), 1, accuracy: 0.0001)
    }
}
