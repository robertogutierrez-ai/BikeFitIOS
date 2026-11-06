import AVFoundation
import Foundation
import Vision

struct AngleRange {
    var minimum: Double
    var maximum: Double
}

struct VideoAnalysisResult {
    let ranges: [JointAngle: AngleRange]
    let validFrames: Int
    let sampledFrames: Int
    let side: String
}

enum VideoAnalyzer {
    private enum Side: CaseIterable {
        case left, right

        var title: String { self == .left ? "izquierdo" : "derecho" }
        var joints: [VNHumanBodyPoseObservation.JointName] {
            switch self {
            case .left:
                return [.leftShoulder, .leftElbow, .leftWrist, .leftHip, .leftKnee, .leftAnkle]
            case .right:
                return [.rightShoulder, .rightElbow, .rightWrist, .rightHip, .rightKnee, .rightAnkle]
            }
        }
    }

    private struct Sample {
        let side: Side
        let angles: [JointAngle: Double]
    }

    static func analyze(url: URL) throws -> VideoAnalysisResult {
        let asset = AVURLAsset(url: url)
        let duration = asset.duration.seconds
        guard duration.isFinite, duration > 0 else { throw AnalysisError.invalidVideo }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1280, height: 1280)
        let request = VNDetectHumanBodyPoseRequest()
        var samples: [Sample] = []
        var sampled = 0
        var time = 0.0
        while time < duration {
            try Task.checkCancellation()
            let image = try generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil)
            sampled += 1
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            if let observation = request.results?.first {
                for side in Side.allCases {
                    if let points = try points(for: side, observation: observation) {
                        let angles = AngleCalculator.calculate(points, width: CGFloat(image.width), height: CGFloat(image.height))
                        if angles.count == JointAngle.allCases.count {
                            samples.append(Sample(side: side, angles: angles))
                        }
                    }
                }
            }
            time += 0.2
        }
        let leftCount = samples.filter { $0.side == .left }.count
        let rightCount = samples.filter { $0.side == .right }.count
        guard max(leftCount, rightCount) > 0 else { throw AnalysisError.noPose }
        let selected: Side = leftCount >= rightCount ? .left : .right
        let validSamples = samples.filter { $0.side == selected }
        var ranges: [JointAngle: AngleRange] = [:]
        for sample in validSamples {
            for (angle, value) in sample.angles {
                if var range = ranges[angle] {
                    range.minimum = min(range.minimum, value)
                    range.maximum = max(range.maximum, value)
                    ranges[angle] = range
                } else {
                    ranges[angle] = AngleRange(minimum: value, maximum: value)
                }
            }
        }
        return VideoAnalysisResult(ranges: ranges, validFrames: validSamples.count, sampledFrames: sampled, side: selected.title)
    }

    private static func points(for side: Side, observation: VNHumanBodyPoseObservation) throws -> BodyPoints? {
        let points = try side.joints.map { try observation.recognizedPoint($0) }
        guard points.allSatisfy({ $0.confidence >= 0.55 }) else { return nil }
        return BodyPoints(
            shoulder: points[0].location, elbow: points[1].location,
            wrist: points[2].location, hip: points[3].location,
            knee: points[4].location, ankle: points[5].location
        )
    }

    enum AnalysisError: LocalizedError {
        case invalidVideo
        case noPose

        var errorDescription: String? {
            switch self {
            case .invalidVideo: return "No se pudo leer la duración del vídeo."
            case .noPose: return "No se pudo detectar una postura completa. Comprueba el encuadre y la iluminación."
            }
        }
    }
}
