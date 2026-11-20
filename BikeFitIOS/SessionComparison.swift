import Foundation

struct RangeDifference {
    let minimum: Double
    let maximum: Double
}

enum SessionComparison {
    static func difference(for angle: JointAngle, baseline: VideoAnalysisResult, comparison: VideoAnalysisResult) -> RangeDifference? {
        guard let first = baseline.ranges[angle], let second = comparison.ranges[angle] else { return nil }
        return RangeDifference(minimum: second.minimum - first.minimum, maximum: second.maximum - first.maximum)
    }
}
