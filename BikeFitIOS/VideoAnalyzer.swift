import AVFoundation
import Foundation
import Vision

struct AngleRange: Codable {
    var minimum: Double
    var maximum: Double
}

struct AngleSample: Codable {
    let time: Double
    let angles: [JointAngle: Double]
}

struct VideoAnalysisResult: Codable {
    let ranges: [JointAngle: AngleRange]
    let validFrames: Int
    let sampledFrames: Int
    let side: String
    var timeline: [AngleSample]? = nil
    var estimatedCycles: Int? = nil
}

enum VideoAnalyzer {
    enum Side: CaseIterable {
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
        let time: Double
        let angles: [JointAngle: Double]
    }

    static func analyze(url: URL, onProgress: @escaping (Double) -> Void) throws -> VideoAnalysisResult {
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
        var lastUpdate = ProcessInfo.processInfo.systemUptime
        onProgress(0)
        while time < duration {
            try Task.checkCancellation()
            let image = try generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil)
            sampled += 1
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            if let observation = request.results?.first {
                for (side, angles) in try measuredAngles(
                    observation: observation, width: CGFloat(image.width), height: CGFloat(image.height)
                ) {
                    samples.append(Sample(side: side, time: time, angles: angles))
                }
            }
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastUpdate >= 0.2 || time + 0.2 >= duration {
                onProgress(progress(after: time, duration: duration))
                lastUpdate = now
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
        var detector = PedalingDetector()
        for sample in validSamples {
            if let knee = sample.angles[.knee] {
                try detector.add(kneeAngle: knee, time: sample.time)
            }
        }
        return VideoAnalysisResult(
            ranges: ranges,
            validFrames: validSamples.count,
            sampledFrames: sampled,
            side: selected.title,
            timeline: validSamples.map { AngleSample(time: $0.time, angles: $0.angles) },
            estimatedCycles: detector.cycles
        )
    }

    static func progress(after sampleTime: Double, duration: Double) -> Double {
        min((sampleTime + 0.2) / duration, 1)
    }

    static func measuredAngles(
        observation: VNHumanBodyPoseObservation, width: CGFloat, height: CGFloat
    ) throws -> [Side: [JointAngle: Double]] {
        var result: [Side: [JointAngle: Double]] = [:]
        for side in Side.allCases {
            if let points = try points(for: side, observation: observation) {
                let angles = AngleCalculator.calculate(points, width: width, height: height)
                if AngleCalculator.requiredAngles.allSatisfy({ angles[$0] != nil }) {
                    result[side] = angles
                }
            }
        }
        return result
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
