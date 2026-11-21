import AVFoundation
import CoreGraphics
import CoreImage
import CoreVideo
import Foundation
import UIKit
import XCTest
@testable import BikeFitIOS

final class AnnotatedVideoRendererTests: XCTestCase {
    func testOverlayPlacesJointAtVisionPosition() throws {
        let joint = CGPoint(x: 0.25, y: 0.25)
        let points = BodyPoints(shoulder: joint, elbow: joint, wrist: joint,
                                hip: joint, knee: joint, ankle: joint)
        let image = try AnnotatedVideoRenderer.makeOverlay(
            points: points, angles: [.knee: 45], side: .left, size: CGSize(width: 400, height: 400)
        )
        let overlay = CIImage(cgImage: image)
        let context = CIContext(options: nil)

        func alpha(x: Int, y: Int) -> UInt8 {
            var bytes = [UInt8](repeating: 0, count: 4)
            bytes.withUnsafeMutableBytes { buffer in
                context.render(overlay, toBitmap: buffer.baseAddress!, rowBytes: 4,
                               bounds: CGRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1),
                               format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
            }
            return bytes[3]
        }

        XCTAssertGreaterThan(alpha(x: 100, y: 100), 0)
        XCTAssertEqual(alpha(x: 100, y: 300), 0)
    }

    func testExportsRotatedVideoWithoutDetectedPose() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }
        let inputURL = directory.appendingPathComponent("input.mov")
        let outputURL = directory.appendingPathComponent("output.mp4")
        let writer = try AVAssetWriter(outputURL: inputURL, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 160,
            AVVideoHeightKey: 90
        ])
        input.transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 90, ty: 0)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        guard writer.canAdd(input) else {
            XCTFail("No se pudo configurar el codificador sintético.")
            return
        }
        writer.add(input)
        guard writer.startWriting() else {
            XCTFail(writer.error?.localizedDescription ?? "No se pudo iniciar el codificador sintético.")
            return
        }
        writer.startSession(atSourceTime: .zero)
        for index in 0..<2 {
            let deadline = Date().addingTimeInterval(10)
            while !input.isReadyForMoreMediaData && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.01)
            }
            guard input.isReadyForMoreMediaData else {
                writer.cancelWriting()
                XCTFail("El codificador no está preparado: \(writer.error?.localizedDescription ?? "sin detalles")")
                return
            }
            var buffer: CVPixelBuffer?
            XCTAssertEqual(CVPixelBufferCreate(nil, 160, 90, kCVPixelFormatType_32BGRA, nil, &buffer), kCVReturnSuccess)
            let pixels = try XCTUnwrap(buffer)
            XCTAssertEqual(CVPixelBufferLockBaseAddress(pixels, []), kCVReturnSuccess)
            let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(pixels))
            memset(base, 255, CVPixelBufferGetBytesPerRow(pixels) * CVPixelBufferGetHeight(pixels))
            XCTAssertEqual(CVPixelBufferUnlockBaseAddress(pixels, []), kCVReturnSuccess)
            guard adaptor.append(pixels, withPresentationTime: CMTime(value: Int64(index), timescale: 2)) else {
                writer.cancelWriting()
                XCTFail(writer.error?.localizedDescription ?? "No se pudo escribir el fotograma sintético.")
                return
            }
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: 1, timescale: 1))
        let written = expectation(description: "Vídeo sintético creado")
        writer.finishWriting { written.fulfill() }
        wait(for: [written], timeout: 30)
        guard writer.status == .completed else {
            writer.cancelWriting()
            XCTFail(writer.error?.localizedDescription ?? "No se pudo finalizar el vídeo sintético.")
            return
        }

        let asset = AVURLAsset(url: inputURL)
        let phases = [PedalingPhase(kind: .top, time: 0.5)]
        let images = try PhaseImageExtractor.extract(from: inputURL, phases: phases)
        let topImage = try XCTUnwrap(images[PedalingPhase.Kind.top.rawValue])
        XCTAssertNotNil(UIImage(data: topImage))
        let store = SessionHistoryStore(directory: directory.appendingPathComponent("sessions", isDirectory: true))
        let saved = try store.save(VideoAnalysisResult(
            ranges: [:], validFrames: 1, sampledFrames: 1, side: "izquierdo", phases: phases
        ))
        try store.savePhaseImages(images, for: saved)
        XCTAssertEqual(try store.phaseImages(for: saved), images)
        try store.delete(saved)
        XCTAssertTrue(try store.phaseImages(for: saved).isEmpty)

        let exporter = try XCTUnwrap(AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720))
        guard exporter.supportedFileTypes.contains(.mp4) else {
            XCTFail("El exportador no admite MP4.")
            return
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        exporter.videoComposition = AnnotatedVideoRenderer.composition(for: asset, side: .left) { _ in nil }
        let exported = expectation(description: "Vídeo anotado exportado")
        exporter.exportAsynchronously { exported.fulfill() }
        wait(for: [exported], timeout: 90)
        guard exporter.status == .completed else {
            exporter.cancelExport()
            XCTFail(exporter.error?.localizedDescription ?? "No se pudo exportar el vídeo sintético.")
            return
        }
        let result = AVURLAsset(url: outputURL)
        XCTAssertGreaterThan(result.duration.seconds, 0.5)
        let generator = AVAssetImageGenerator(asset: result)
        generator.appliesPreferredTrackTransform = true
        let frame = try generator.copyCGImage(at: .zero, actualTime: nil)
        XCTAssertLessThan(frame.width, frame.height)
        XCTAssertEqual(Double(frame.width) / Double(frame.height), 90.0 / 160.0, accuracy: 0.03)

        let mediaPipeURL = directory.appendingPathComponent("mediapipe.mp4")
        let mediaPipeExporter = try XCTUnwrap(AVAssetExportSession(
            asset: asset, presetName: AVAssetExportPreset1280x720
        ))
        mediaPipeExporter.outputURL = mediaPipeURL
        mediaPipeExporter.outputFileType = .mp4
        mediaPipeExporter.videoComposition = try AnnotatedVideoRenderer.mediaPipeComposition(for: asset, side: .left)
        let mediaPipeExported = expectation(description: "Vídeo anotado MediaPipe exportado")
        mediaPipeExporter.exportAsynchronously { mediaPipeExported.fulfill() }
        wait(for: [mediaPipeExported], timeout: 90)
        guard mediaPipeExporter.status == .completed else {
            mediaPipeExporter.cancelExport()
            XCTFail(mediaPipeExporter.error?.localizedDescription ?? "No se pudo exportar MediaPipe.")
            return
        }
        let mediaPipeResult = AVURLAsset(url: mediaPipeURL)
        XCTAssertGreaterThan(mediaPipeResult.duration.seconds, 0.5)
        let mediaPipeGenerator = AVAssetImageGenerator(asset: mediaPipeResult)
        mediaPipeGenerator.appliesPreferredTrackTransform = true
        let mediaPipeFrame = try mediaPipeGenerator.copyCGImage(at: .zero, actualTime: nil)
        XCTAssertLessThan(mediaPipeFrame.width, mediaPipeFrame.height)

        let failingExporter = try XCTUnwrap(AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720))
        failingExporter.outputURL = directory.appendingPathComponent("failure.mp4")
        failingExporter.outputFileType = .mp4
        failingExporter.videoComposition = AnnotatedVideoRenderer.composition(for: asset, side: .left) { _ in
            throw PoseError.simulated
        }
        let failed = expectation(description: "Error de detección propagado")
        failingExporter.exportAsynchronously { failed.fulfill() }
        wait(for: [failed], timeout: 90)
        XCTAssertEqual(failingExporter.status, .failed)
        XCTAssertNotNil(failingExporter.error)
    }

    private enum PoseError: Error {
        case simulated
    }
}
