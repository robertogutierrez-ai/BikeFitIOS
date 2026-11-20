import Foundation

enum ExperimentalScore {
    struct Metric {
        let angle: JointAngle
        let measured: Int
        let inRange: Int
    }

    struct Result {
        let value: Double
        let metrics: [Metric]
    }

    enum Evaluation {
        case available(Result)
        case unavailable(String)
    }

    static func calculate(result: VideoAnalysisResult, profile: ReferenceProfile) -> Evaluation {
        guard result.sampledFrames >= 15, result.validFrames >= 0,
              result.validFrames <= result.sampledFrames else {
            return .unavailable("Se necesitan al menos 15 fotogramas muestreados con recuentos válidos.")
        }
        guard let samples = result.timeline, samples.count == result.validFrames else {
            return .unavailable("Esta sesión no dispone de todas las muestras necesarias.")
        }
        guard !profile.ranges.isEmpty else {
            return .unavailable("El perfil no contiene referencias.")
        }
        let minimumCount = Int(ceil(Double(result.sampledFrames) * 0.8))
        var metrics: [Metric] = []
        for angle in JointAngle.allCases {
            guard let reference = profile.ranges[angle] else { continue }
            guard reference.minimum.isFinite, reference.maximum.isFinite,
                  reference.minimum <= reference.maximum else {
                return .unavailable("La referencia de \(angle.rawValue) no es válida.")
            }
            let values = samples.compactMap { $0.angles[angle] }
            guard values.allSatisfy(\.isFinite) else {
                return .unavailable("Las muestras de \(angle.rawValue) no son válidas.")
            }
            guard values.count >= minimumCount else {
                return .unavailable("No hay suficientes muestras de \(angle.rawValue): \(values.count) de \(result.sampledFrames); se requiere al menos el 80 %.")
            }
            metrics.append(Metric(
                angle: angle, measured: values.count,
                inRange: values.filter { $0 >= reference.minimum && $0 <= reference.maximum }.count
            ))
        }
        guard !metrics.isEmpty else {
            return .unavailable("El perfil no contiene referencias compatibles.")
        }
        let score = metrics.reduce(0.0) { $0 + Double($1.inRange) / Double($1.measured) }
            / Double(metrics.count) * 100
        return .available(Result(value: score, metrics: metrics))
    }
}
