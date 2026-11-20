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

enum AnalysisEngine: String, Codable {
    case vision = "Apple Vision"
    case mediaPipe = "MediaPipe"
}

struct VideoAnalysisResult: Codable {
    let ranges: [JointAngle: AngleRange]
    let validFrames: Int
    let sampledFrames: Int
    let side: String
    var timeline: [AngleSample]? = nil
    var estimatedCycles: Int? = nil
    var engine: AnalysisEngine? = nil
    var kops: KopsVideoResult? = nil
    var phases: [PedalingPhase]? = nil
    var kneeHorizontalSpreadPercent: Double? = nil
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
        let points: BodyPoints?
    }

    static func analyze(
        url: URL, engine: AnalysisEngine = .vision, kopsCalibration: KopsCalibration? = nil,
        onProgress: @escaping (Double) -> Void
    ) throws -> VideoAnalysisResult {
        if let calibration = kopsCalibration {
            guard engine == .mediaPipe, calibration.millimetersPerImageWidth.isFinite,
                  calibration.millimetersPerImageWidth > 0 else { throw AnalysisError.invalidCalibration }
        }
        let asset = AVURLAsset(url: url)
        let duration = asset.duration.seconds
        guard duration.isFinite, duration > 0 else { throw AnalysisError.invalidVideo }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1280, height: 1280)
        let estimator: PoseEstimator
        switch engine {
        case .vision: estimator = .vision(VNDetectHumanBodyPoseRequest())
        case .mediaPipe: estimator = .mediaPipe(try MediaPipePoseEstimator())
        }
        var samples: [Sample] = []
        var sampled = 0
        var time = 0.0
        var lastUpdate = ProcessInfo.processInfo.systemUptime
        onProgress(0)
        while time < duration {
            try Task.checkCancellation()
            let image = try generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil)
            sampled += 1
            for (side, measurement) in try estimator.measure(image: image, time: time) {
                samples.append(Sample(side: side, time: time, angles: measurement.angles, points: measurement.points))
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
        var phaseTracker = PedalingPhases()
        for sample in validSamples {
            if let knee = sample.angles[.knee] {
                try detector.add(kneeAngle: knee, time: sample.time)
            }
            if let points = sample.points { phaseTracker.add(points: points, time: sample.time) }
        }
        var kopsResult: KopsVideoResult?
        if let calibration = kopsCalibration {
            var tracker = KopsVideoTracker(calibration: calibration)
            for sample in validSamples {
                if let points = sample.points {
                    tracker.add(points: points, time: sample.time)
                }
            }
            kopsResult = tracker.result
        }
        return VideoAnalysisResult(
            ranges: ranges,
            validFrames: validSamples.count,
            sampledFrames: sampled,
            side: selected.title,
            timeline: validSamples.map { AngleSample(time: $0.time, angles: $0.angles) },
            estimatedCycles: detector.cycles,
            engine: engine,
            kops: kopsResult,
            phases: phaseTracker.phases(cycles: detector.cycles, calibratedFacingRight: kopsCalibration?.facingRight),
            kneeHorizontalSpreadPercent: phaseTracker.kneeHorizontalSpreadPercent
        )
    }

    private struct Measurement {
        let angles: [JointAngle: Double]
        let points: BodyPoints?
    }

    private enum PoseEstimator {
        case vision(VNDetectHumanBodyPoseRequest)
        case mediaPipe(MediaPipePoseEstimator)

        func measure(image: CGImage, time: Double) throws -> [Side: Measurement] {
            switch self {
            case .vision(let request):
                try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
                guard let observation = request.results?.first else { return [:] }
                var measured: [Side: Measurement] = [:]
                for side in Side.allCases {
                    if let points = try VideoAnalyzer.points(for: side, observation: observation) {
                        let angles = AngleCalculator.calculate(points, width: CGFloat(image.width), height: CGFloat(image.height))
                        if AngleCalculator.requiredAngles.allSatisfy({ angles[$0] != nil }) {
                            measured[side] = Measurement(angles: angles, points: points)
                        }
                    }
                }
                return measured
            case .mediaPipe(let estimator):
                return try estimator.measure(image: image, time: time).mapValues {
                    Measurement(angles: $0.angles, points: $0.points)
                }
            }
        }
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

    static func points(for side: Side, observation: VNHumanBodyPoseObservation) throws -> BodyPoints? {
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
        case invalidCalibration
        case noPose

        var errorDescription: String? {
            switch self {
            case .invalidVideo: return "No se pudo leer la duración del vídeo."
            case .invalidCalibration: return "La calibración KOPS no es válida para el motor seleccionado."
            case .noPose: return "No se pudo detectar una postura completa. Comprueba el encuadre y la iluminación."
            }
        }
    }
}
