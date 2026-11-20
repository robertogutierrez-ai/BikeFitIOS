import CoreGraphics
import Foundation

struct KopsMeasurement {
    let offsetMillimeters: Double

    static func calculate(referenceStart: CGPoint, referenceEnd: CGPoint, knee: CGPoint,
                          pedal: CGPoint, referenceMillimeters: Double) -> KopsMeasurement? {
        let points = [referenceStart, referenceEnd, knee, pedal]
        guard points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
              referenceMillimeters.isFinite, (1...5000).contains(referenceMillimeters) else { return nil }
        let referenceDistance = hypot(referenceEnd.x - referenceStart.x, referenceEnd.y - referenceStart.y)
        guard referenceDistance.isFinite, referenceDistance >= 0.02 else { return nil }
        let offset = Double(knee.x - pedal.x) * referenceMillimeters / Double(referenceDistance)
        guard offset.isFinite else { return nil }
        return KopsMeasurement(offsetMillimeters: offset)
    }
}
