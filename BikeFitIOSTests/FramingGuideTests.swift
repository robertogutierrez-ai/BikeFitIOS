import XCTest
@testable import BikeFitIOS

final class FramingGuideTests: XCTestCase {
    func testFrameKeepsEightPercentMarginInPortrait() {
        assertFrame(in: CGSize(width: 300, height: 600))
    }

    func testFrameKeepsEightPercentMarginInLandscape() {
        assertFrame(in: CGSize(width: 600, height: 300))
    }

    private func assertFrame(in size: CGSize) {
        let frame = FramingGuideLayout.frame(in: size)
        XCTAssertEqual(frame.minX, size.width * 0.08, accuracy: 0.001)
        XCTAssertEqual(frame.maxX, size.width * 0.92, accuracy: 0.001)
        XCTAssertEqual(frame.minY, size.height * 0.08, accuracy: 0.001)
        XCTAssertEqual(frame.maxY, size.height * 0.92, accuracy: 0.001)
        XCTAssertEqual(frame.midX, size.width / 2, accuracy: 0.001)
        XCTAssertEqual(frame.midY, size.height / 2, accuracy: 0.001)
    }
}
