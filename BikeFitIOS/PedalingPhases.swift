import CoreGraphics
import Foundation

struct PedalingPhase: Codable {
    enum Kind: String, Codable {
        case top, bottom, forward
        var title: String {
            switch self {
            case .top: return "Tobillo más alto"
            case .bottom: return "Tobillo más bajo"
            case .forward: return "Tobillo más adelantado"
            }
        }
    }
    let kind: Kind
    let time: Double
}

struct PedalingPhases {
    private var highest: (y: CGFloat, time: Double)?
    private var lowest: (y: CGFloat, time: Double)?
    private var leftmost: (x: CGFloat, time: Double)?
    private var rightmost: (x: CGFloat, time: Double)?
    private var facingLeft = 0
    private var facingRight = 0
    private var kneeXs: [Double] = []

    mutating func add(points: BodyPoints, time: Double) {
        guard time.isFinite, time >= 0, points.ankle.x.isFinite, points.ankle.y.isFinite,
              points.knee.x.isFinite, points.hip.x.isFinite,
              (0...1).contains(points.ankle.x), (0...1).contains(points.ankle.y),
              (0...1).contains(points.knee.x), (0...1).contains(points.hip.x) else { return }
        if highest.map({ points.ankle.y > $0.y }) ?? true { highest = (points.ankle.y, time) }
        if lowest.map({ points.ankle.y < $0.y }) ?? true { lowest = (points.ankle.y, time) }
        if leftmost.map({ points.ankle.x < $0.x }) ?? true { leftmost = (points.ankle.x, time) }
        if rightmost.map({ points.ankle.x > $0.x }) ?? true { rightmost = (points.ankle.x, time) }
        let direction = points.knee.x - points.hip.x
        if direction > 0.02 { facingRight += 1 }
        if direction < -0.02 { facingLeft += 1 }
        kneeXs.append(Double(points.knee.x))
    }

    func phases(cycles: Int, calibratedFacingRight: Bool? = nil) -> [PedalingPhase] {
        guard cycles > 0, let highest = highest, let lowest = lowest,
              highest.y - lowest.y >= 0.02 else { return [] }
        var result = [PedalingPhase(kind: .top, time: highest.time),
                      PedalingPhase(kind: .bottom, time: lowest.time)]
        let count = facingRight + facingLeft
        let inferred: Bool? = count >= 3 && Double(max(facingRight, facingLeft)) / Double(count) >= 0.8
            ? facingRight > facingLeft : nil
        if let direction = calibratedFacingRight ?? inferred,
           let front = direction ? rightmost : leftmost {
            result.append(PedalingPhase(kind: .forward, time: front.time))
        }
        return result
    }

    var kneeHorizontalSpreadPercent: Double? {
        guard kneeXs.count >= 2 else { return nil }
        let mean = kneeXs.reduce(0, +) / Double(kneeXs.count)
        let variance = kneeXs.reduce(0) { $0 + pow($1 - mean, 2) } / Double(kneeXs.count)
        return sqrt(variance) * 100
    }
}
