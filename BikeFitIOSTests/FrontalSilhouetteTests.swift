import CoreVideo
import XCTest
@testable import BikeFitIOS

final class FrontalSilhouetteTests: XCTestCase {
    func testCountsMaskPixelsAndDetectsClipping() throws {
        var buffer: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(nil, 4, 4, kCVPixelFormatType_OneComponent8, nil, &buffer), kCVReturnSuccess)
        let mask = try XCTUnwrap(buffer)
        XCTAssertEqual(CVPixelBufferLockBaseAddress(mask, []), kCVReturnSuccess)
        let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(mask)).assumingMemoryBound(to: UInt8.self)
        let stride = CVPixelBufferGetBytesPerRow(mask)
        for y in 0..<4 {
            for x in 0..<4 { base[y * stride + x] = 0 }
        }
        base[stride + 1] = 127
        base[stride + 2] = 128
        base[2 * stride + 2] = 255
        XCTAssertEqual(CVPixelBufferUnlockBaseAddress(mask, []), kCVReturnSuccess)
        let measured = try FrontalSilhouette.measure(mask: mask)
        XCTAssertEqual(measured.foregroundPixels, 2)
        XCTAssertFalse(measured.touchesEdge)
        XCTAssertEqual(measured.fraction, 0.125, accuracy: 0.001)
        XCTAssertEqual(CVPixelBufferLockBaseAddress(mask, []), kCVReturnSuccess)
        let relocked = try XCTUnwrap(CVPixelBufferGetBaseAddress(mask)).assumingMemoryBound(to: UInt8.self)
        relocked[0] = 255
        XCTAssertEqual(CVPixelBufferUnlockBaseAddress(mask, []), kCVReturnSuccess)
        XCTAssertTrue(try FrontalSilhouette.measure(mask: mask).touchesEdge)
    }

    func testComparesOccupancyAndRejectsMissingClippedOrMismatchedMasks() throws {
        let first = SilhouetteArea(foregroundPixels: 2, width: 4, height: 4, touchesEdge: false)
        let second = SilhouetteArea(foregroundPixels: 4, width: 4, height: 4, touchesEdge: false)
        let result = try FrontalSilhouette.compare(first, second)
        XCTAssertEqual(result.firstFraction, 0.125, accuracy: 0.001)
        XCTAssertEqual(result.secondFraction, 0.25, accuracy: 0.001)
        XCTAssertEqual(result.relativeChange, 100, accuracy: 0.001)
        XCTAssertThrowsError(try FrontalSilhouette.compare(first, SilhouetteArea(
            foregroundPixels: 0, width: 4, height: 4, touchesEdge: false)))
        XCTAssertThrowsError(try FrontalSilhouette.compare(first, SilhouetteArea(
            foregroundPixels: 2, width: 4, height: 4, touchesEdge: true)))
        XCTAssertThrowsError(try FrontalSilhouette.compare(first, SilhouetteArea(
            foregroundPixels: 2, width: 5, height: 4, touchesEdge: false)))
    }
}
