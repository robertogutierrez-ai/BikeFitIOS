import CoreGraphics
import CoreImage
import CoreVideo
import Foundation
import MediaPipeTasksVision
import UIKit

struct MediaPipeLandmark {
    let x: Float
    let y: Float
    let visibility: Float?
    let presence: Float?
}

struct MediaPipeMeasurement {
    let angles: [JointAngle: Double]
    let points: BodyPoints
}

final class MediaPipePoseEstimator {
    enum Mode {
        case video, image
    }

    private let landmarker: PoseLandmarker
    private let mode: Mode

    init(mode: Mode = .video) throws {
        guard let model = Bundle.main.path(forResource: "pose_landmarker_full", ofType: "task") else {
            throw PoseError.modelMissing
        }
        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = model
        options.runningMode = mode == .video ? .video : .image
        options.numPoses = 1
        self.mode = mode
        landmarker = try PoseLandmarker(options: options)
    }

    func measure(image: CGImage, time: Double) throws -> [VideoAnalyzer.Side: MediaPipeMeasurement] {
        guard time.isFinite, time >= 0, time < Double(Int.max) / 1000 else { throw PoseError.invalidTimestamp }
        let rgba = try Self.rgbaImage(image)
        let input = try MPImage(uiImage: UIImage(cgImage: rgba))
        let result: PoseLandmarkerResult
        switch mode {
        case .video:
            result = try landmarker.detect(videoFrame: input, timestampInMilliseconds: Int((time * 1000).rounded()))
        case .image:
            result = try landmarker.detect(image: input)
        }
        guard let pose = result.landmarks.first else { return [:] }
        guard pose.count >= 33 else { throw PoseError.invalidLandmarks }
        let landmarks = pose.map {
            MediaPipeLandmark(x: $0.x, y: $0.y, visibility: $0.visibility?.floatValue, presence: $0.presence?.floatValue)
        }
        var measured: [VideoAnalyzer.Side: MediaPipeMeasurement] = [:]
        for side in VideoAnalyzer.Side.allCases {
            if let points = Self.points(landmarks, side: side) {
                let angles = AngleCalculator.calculate(points, width: CGFloat(image.width), height: CGFloat(image.height))
                if AngleCalculator.requiredAngles.allSatisfy({ angles[$0] != nil }) {
                    measured[side] = MediaPipeMeasurement(angles: angles, points: points)
                }
            }
        }
        return measured
    }

    func measure(pixelBuffer: CVPixelBuffer, time: Double, context: CIContext) throws -> [VideoAnalyzer.Side: MediaPipeMeasurement] {
        let source = CIImage(cvPixelBuffer: pixelBuffer)
        guard let frame = context.createCGImage(source, from: source.extent) else {
            throw PoseError.invalidImage
        }
        return try measure(image: frame, time: time)
    }

    static func points(_ landmarks: [MediaPipeLandmark], side: VideoAnalyzer.Side) -> BodyPoints? {
        guard landmarks.count >= 33 else { return nil }
        let indices = side == .left ? [11, 13, 15, 23, 25, 27, 31] : [12, 14, 16, 24, 26, 28, 32]
        func point(_ index: Int) -> CGPoint? {
            let landmark = landmarks[index]
            guard let visibility = landmark.visibility, let presence = landmark.presence,
                  visibility.isFinite, presence.isFinite, visibility >= 0.55, presence >= 0.55,
                  landmark.x.isFinite, landmark.y.isFinite,
                  (0...1).contains(landmark.x), (0...1).contains(landmark.y) else { return nil }
            return CGPoint(x: CGFloat(landmark.x), y: CGFloat(1 - landmark.y))
        }
        guard let shoulder = point(indices[0]), let elbow = point(indices[1]),
              let wrist = point(indices[2]), let hip = point(indices[3]),
              let knee = point(indices[4]), let ankle = point(indices[5]) else { return nil }
        return BodyPoints(shoulder: shoulder, elbow: elbow, wrist: wrist, hip: hip,
                          knee: knee, ankle: ankle, foot: point(indices[6]))
    }

    static func rgbaImage(_ image: CGImage) throws -> CGImage {
        guard let context = CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { throw PoseError.invalidImage }
        context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
        guard let converted = context.makeImage() else { throw PoseError.invalidImage }
        return converted
    }

    private enum PoseError: LocalizedError {
        case modelMissing, invalidImage, invalidTimestamp, invalidLandmarks

        var errorDescription: String? {
            switch self {
            case .modelMissing: return "Falta el modelo de MediaPipe en la aplicación."
            case .invalidImage: return "No se pudo preparar el fotograma para MediaPipe."
            case .invalidTimestamp: return "El instante del fotograma no es válido."
            case .invalidLandmarks: return "MediaPipe devolvió una pose incompleta."
            }
        }
    }
}
