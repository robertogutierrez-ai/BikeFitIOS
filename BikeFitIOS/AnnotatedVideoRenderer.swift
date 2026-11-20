import AVFoundation
import CoreImage
import CoreText
import Foundation
import Vision

enum AnnotatedVideoRenderer {
    static func composition(for asset: AVAsset, side: VideoAnalyzer.Side) -> AVVideoComposition {
        composition(for: asset, side: side, detectPose: detectPose(in:))
    }

    static func composition(
        for asset: AVAsset, side: VideoAnalyzer.Side,
        detectPose: @escaping (CIImage) throws -> VNHumanBodyPoseObservation?
    ) -> AVVideoComposition {
        AVVideoComposition(asset: asset) { request in
            do {
                let source = request.sourceImage
                let extent = source.extent
                guard extent.minX.isFinite, extent.minY.isFinite,
                      extent.width.isFinite, extent.height.isFinite,
                      extent.width > 0, extent.height > 0 else { throw RenderError.invalidFrame }
                guard let observation = try detectPose(source),
                      let points = try VideoAnalyzer.points(for: side, observation: observation) else {
                    request.finish(with: source, context: nil)
                    return
                }
                let angles = AngleCalculator.calculate(points, width: extent.width, height: extent.height)
                guard AngleCalculator.requiredAngles.allSatisfy({ angles[$0] != nil }) else {
                    request.finish(with: source, context: nil)
                    return
                }
                let overlay = try makeOverlay(points: points, angles: angles, side: side, size: extent.size)
                let translated = CIImage(cgImage: overlay)
                    .transformed(by: CGAffineTransform(
                        scaleX: extent.width / CGFloat(overlay.width),
                        y: extent.height / CGFloat(overlay.height)
                    ))
                    .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
                request.finish(with: translated.composited(over: source).cropped(to: extent), context: nil)
            } catch {
                request.finish(with: error)
            }
        }
    }

    private static func detectPose(in image: CIImage) throws -> VNHumanBodyPoseObservation? {
        let extent = image.extent
        let scale = min(1, 1280 / max(extent.width, extent.height))
        let visionImage = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let request = VNDetectHumanBodyPoseRequest()
        try VNImageRequestHandler(ciImage: visionImage, orientation: .up, options: [:]).perform([request])
        return request.results?.first
    }

    private static func pixelPoint(_ point: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    static func makeOverlay(
        points: BodyPoints, angles: [JointAngle: Double], side: VideoAnalyzer.Side, size: CGSize
    ) throws -> CGImage {
        let scale = min(1, 1280 / max(size.width, size.height))
        let width = max(1, Int((size.width * scale).rounded()))
        let height = max(1, Int((size.height * scale).rounded()))
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { throw RenderError.drawingFailed }
        let canvas = CGSize(width: CGFloat(width), height: CGFloat(height))
        context.clear(CGRect(origin: .zero, size: canvas))
        let joints = [points.wrist, points.elbow, points.shoulder, points.hip, points.knee, points.ankle]
            .map { pixelPoint($0, size: canvas) }
        let lineWidth = max(2, CGFloat(width) / 300)
        context.setStrokeColor(CGColor(red: 0.1, green: 1, blue: 0.4, alpha: 1))
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.addLines(between: joints)
        context.strokePath()
        context.setFillColor(CGColor(red: 1, green: 0.35, blue: 0.1, alpha: 1))
        for joint in joints {
            context.fillEllipse(in: CGRect(x: joint.x - lineWidth, y: joint.y - lineWidth,
                                           width: lineWidth * 2, height: lineWidth * 2))
        }

        let fontSize = max(12, CGFloat(width) / 55)
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String):
                CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        ]
        let lines = ["BikeFit · lado \(side.title)"] + AngleCalculator.requiredAngles.compactMap { angle in
            angles[angle].map { "\(angle.rawValue): \(String(format: "%.1f°", $0))" }
        }
        let textLines = lines.map {
            CTLineCreateWithAttributedString(NSAttributedString(string: $0, attributes: attributes) as CFAttributedString)
        }
        let textWidth = textLines.map { CGFloat(CTLineGetTypographicBounds($0, nil, nil, nil)) }.max() ?? 0
        let padding = fontSize * 0.5
        let lineHeight = fontSize * 1.35
        let panelHeight = lineHeight * CGFloat(textLines.count) + padding * 2
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.7))
        context.fill(CGRect(x: 0, y: CGFloat(height) - panelHeight,
                            width: min(CGFloat(width), textWidth + padding * 2), height: panelHeight))
        context.textMatrix = .identity
        for (index, line) in textLines.enumerated() {
            context.textPosition = CGPoint(x: padding, y: CGFloat(height) - padding - fontSize - CGFloat(index) * lineHeight)
            CTLineDraw(line, context)
        }
        guard let image = context.makeImage() else { throw RenderError.drawingFailed }
        return image
    }

    private enum RenderError: LocalizedError {
        case invalidFrame, drawingFailed

        var errorDescription: String? {
            switch self {
            case .invalidFrame: return "El fotograma del vídeo no es válido."
            case .drawingFailed: return "No se pudo dibujar la postura."
            }
        }
    }
}
