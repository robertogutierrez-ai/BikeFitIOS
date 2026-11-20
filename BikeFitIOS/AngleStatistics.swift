import Foundation

struct AngleStatistics {
    let count: Int
    let mean: Double
    let standardDeviation: Double
    let amplitude: Double

    static func calculate(for angle: JointAngle, samples: [AngleSample]) -> AngleStatistics? {
        let values = samples.compactMap { $0.angles[angle] }
        guard let minimum = values.min(), let maximum = values.max() else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        return AngleStatistics(
            count: values.count, mean: mean,
            standardDeviation: sqrt(variance), amplitude: maximum - minimum
        )
    }
}
