import Foundation

struct LiveSessionAccumulator {
    private struct SideData {
        var recent: [[JointAngle: Double]] = []
        var samples: [AngleSample] = []
        var detector = PedalingDetector()
        var motion = PedalingMotion()
        var lastTime: Double?
    }

    private var data: [VideoAnalyzer.Side: SideData] = [:]
    private var startTime: Double?
    private var previousTime: Double?
    private(set) var sampledFrames = 0
    private let engine: AnalysisEngine

    init(engine: AnalysisEngine = .vision) {
        self.engine = engine
    }

    mutating func add(time: Double, measured: [VideoAnalyzer.Side: [JointAngle: Double]]) throws {
        guard time.isFinite, previousTime.map({ time > $0 }) ?? true else { throw SampleError.invalidTime }
        if startTime == nil { startTime = time }
        guard let start = startTime else { throw SampleError.invalidTime }
        previousTime = time
        let relative = time - start
        sampledFrames += 1
        for side in VideoAnalyzer.Side.allCases {
            guard let angles = measured[side], let knee = angles[.knee], knee.isFinite,
                  angles.values.allSatisfy(\.isFinite) else {
                data[side]?.recent = []
                data[side]?.motion.reset()
                continue
            }
            var state = data[side] ?? SideData()
            if let last = state.lastTime, relative - last > 1.5 {
                state.recent = []
                state.motion.reset()
            }
            state.recent.append(angles)
            if state.recent.count > 4 { state.recent.removeFirst() }
            var smoothed: [JointAngle: Double] = [:]
            for angle in angles.keys {
                let values = state.recent.compactMap { $0[angle] }
                smoothed[angle] = values.reduce(0, +) / Double(values.count)
            }
            try state.detector.add(kneeAngle: knee, time: relative)
            if let smoothedKnee = smoothed[.knee] {
                state.motion.add(kneeAngle: smoothedKnee, time: relative)
            }
            state.samples.append(AngleSample(time: relative, angles: smoothed))
            state.lastTime = relative
            data[side] = state
        }
    }

    func result() throws -> VideoAnalysisResult {
        let left = data[.left]?.samples.count ?? 0
        let right = data[.right]?.samples.count ?? 0
        guard max(left, right) > 0 else { throw SampleError.noPose }
        let side: VideoAnalyzer.Side = left >= right ? .left : .right
        guard let state = data[side] else { throw SampleError.noPose }
        var ranges: [JointAngle: AngleRange] = [:]
        for sample in state.samples {
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
        return VideoAnalysisResult(ranges: ranges, validFrames: state.samples.count,
                                   sampledFrames: sampledFrames, side: side.title,
                                   timeline: state.samples, estimatedCycles: state.detector.cycles, engine: engine)
    }

    func latest(for side: VideoAnalyzer.Side) -> [JointAngle: Double]? {
        data[side]?.samples.last?.angles
    }

    func isPedaling(for side: VideoAnalyzer.Side) -> Bool {
        data[side]?.motion.detected ?? false
    }

    private enum SampleError: LocalizedError {
        case invalidTime, noPose
        var errorDescription: String? {
            switch self {
            case .invalidTime: return "Los tiempos de la sesión no son válidos."
            case .noPose: return "No se detectó una postura completa durante la sesión."
            }
        }
    }
}
