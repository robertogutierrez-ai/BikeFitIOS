import Foundation

struct RangeDifference {
    let minimum: Double
    let maximum: Double
}

struct MeanDifference {
    let value: Double
    let baselineCount: Int
    let comparisonCount: Int
}

enum SessionComparison {
    enum Mode: String, CaseIterable {
        case general = "General"
        case beforeAfter = "Antes/después"
        case bilateral = "Bilateral"
    }

    static func unavailableReason(
        mode: Mode, baseline: VideoAnalysisResult, comparison: VideoAnalysisResult
    ) -> String? {
        guard mode != .general else { return nil }
        guard (baseline.engine ?? .vision) == (comparison.engine ?? .vision) else {
            return "Selecciona sesiones analizadas con el mismo motor."
        }
        let sides = VideoAnalyzer.Side.allCases.map(\.title)
        guard sides.contains(baseline.side), sides.contains(comparison.side) else {
            return "Las sesiones deben indicar un lado válido."
        }
        switch mode {
        case .beforeAfter:
            return baseline.side == comparison.side ? nil : "Para antes/después selecciona el mismo lado en ambas sesiones."
        case .bilateral:
            return baseline.side != comparison.side ? nil : "Para la comparación bilateral selecciona un lado izquierdo y otro derecho."
        case .general:
            return nil
        }
    }

    static func difference(for angle: JointAngle, baseline: VideoAnalysisResult, comparison: VideoAnalysisResult) -> RangeDifference? {
        guard let first = baseline.ranges[angle], let second = comparison.ranges[angle] else { return nil }
        return RangeDifference(minimum: second.minimum - first.minimum, maximum: second.maximum - first.maximum)
    }

    static func meanDifference(
        for angle: JointAngle, baseline: VideoAnalysisResult, comparison: VideoAnalysisResult
    ) -> MeanDifference? {
        guard let first = baseline.timeline, let second = comparison.timeline,
              let firstStats = AngleStatistics.calculate(for: angle, samples: first),
              let secondStats = AngleStatistics.calculate(for: angle, samples: second) else { return nil }
        return MeanDifference(value: secondStats.mean - firstStats.mean,
                              baselineCount: firstStats.count, comparisonCount: secondStats.count)
    }
}
