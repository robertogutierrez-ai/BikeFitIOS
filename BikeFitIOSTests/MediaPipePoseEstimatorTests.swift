import CoreImage
import CoreVideo
import XCTest
@testable import BikeFitIOS

final class MediaPipePoseEstimatorTests: XCTestCase {
    func testExtractsCorrectSideAndOmitsFootWithoutConfidence() throws {
        let valid = MediaPipeLandmark(x: 0.25, y: 0.2, visibility: 0.9, presence: 0.9)
        var landmarks = Array(repeating: valid, count: 33)
        landmarks[31] = MediaPipeLandmark(x: 0.7, y: 0.8, visibility: 0.9, presence: 0.9)
        landmarks[32] = MediaPipeLandmark(x: 0.1, y: 0.4, visibility: 0.1, presence: 0.9)
        let left = try XCTUnwrap(MediaPipePoseEstimator.points(landmarks, side: .left))
        let leftFoot = try XCTUnwrap(left.foot)
        XCTAssertEqual(leftFoot.x, 0.7, accuracy: 0.0001)
        XCTAssertEqual(leftFoot.y, 0.2, accuracy: 0.0001)
        let right = try XCTUnwrap(MediaPipePoseEstimator.points(landmarks, side: .right))
        XCTAssertNil(right.foot)
        landmarks[26] = MediaPipeLandmark(x: 0.1, y: 0.4, visibility: 0.9, presence: nil)
        XCTAssertNil(MediaPipePoseEstimator.points(landmarks, side: .right))
    }

    func testRejectsIncompleteOrOutOfBoundsPose() {
        let valid = MediaPipeLandmark(x: 0.5, y: 0.5, visibility: 1, presence: 1)
        XCTAssertNil(MediaPipePoseEstimator.points(Array(repeating: valid, count: 32), side: .left))
        var landmarks = Array(repeating: valid, count: 33)
        landmarks[27] = MediaPipeLandmark(x: 1.2, y: 0.5, visibility: 1, presence: 1)
        XCTAssertNil(MediaPipePoseEstimator.points(landmarks, side: .left))
    }

    func testRGBAConversionPreservesImageOrientation() throws {
        let context = CIContext(options: nil)
        let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0))
            .cropped(to: CGRect(x: 0, y: 0, width: 40, height: 20))
        let blue = CIImage(color: CIColor(red: 0, green: 0, blue: 1))
            .cropped(to: CGRect(x: 0, y: 20, width: 40, height: 20))
        let source = try XCTUnwrap(context.createCGImage(blue.composited(over: red),
                                                         from: CGRect(x: 0, y: 0, width: 40, height: 40)))
        let converted = try MediaPipePoseEstimator.rgbaImage(source)

        func pixel(_ image: CGImage, y: CGFloat) -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: 4)
            bytes.withUnsafeMutableBytes { buffer in
                context.render(CIImage(cgImage: image), toBitmap: buffer.baseAddress!, rowBytes: 4,
                               bounds: CGRect(x: 10, y: y, width: 1, height: 1),
                               format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
            }
            return bytes
        }
        XCTAssertEqual(pixel(source, y: 10), pixel(converted, y: 10))
        XCTAssertEqual(pixel(source, y: 30), pixel(converted, y: 30))
    }

    func testBundledModelCanAnalyzeEmptyImage() throws {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 160, height: 160, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 160, height: 160))
        let image = try XCTUnwrap(context.makeImage())
        let estimator = try MediaPipePoseEstimator()
        XCTAssertTrue(try estimator.measure(image: image, time: 0).isEmpty)
        let imageEstimator = try MediaPipePoseEstimator(mode: .image)
        XCTAssertTrue(try imageEstimator.measure(image: image, time: 0).isEmpty)
        XCTAssertTrue(try imageEstimator.measure(image: image, time: 0).isEmpty)
    }

    func testVideoModeAnalyzesCameraPixelBuffersInOrder() throws {
        var buffer: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(nil, 160, 160, kCVPixelFormatType_32BGRA, nil, &buffer), kCVReturnSuccess)
        let pixelBuffer = try XCTUnwrap(buffer)
        XCTAssertEqual(CVPixelBufferLockBaseAddress(pixelBuffer, []), kCVReturnSuccess)
        let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(pixelBuffer))
        memset(base, 255, CVPixelBufferGetBytesPerRow(pixelBuffer) * CVPixelBufferGetHeight(pixelBuffer))
        XCTAssertEqual(CVPixelBufferUnlockBaseAddress(pixelBuffer, []), kCVReturnSuccess)
        let estimator = try MediaPipePoseEstimator()
        let context = CIContext()
        XCTAssertTrue(try estimator.measure(pixelBuffer: pixelBuffer, time: 0, context: context).isEmpty)
        XCTAssertTrue(try estimator.measure(pixelBuffer: pixelBuffer, time: 0.2, context: context).isEmpty)
    }
}
