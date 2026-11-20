import CoreGraphics
import Foundation

struct KopsMeasurement {
    let offsetMillimeters: Double

    static func scale(referenceStart: CGPoint, referenceEnd: CGPoint, millimeters: Double) -> Double? {
        guard referenceStart.x.isFinite, referenceStart.y.isFinite,
              referenceEnd.x.isFinite, referenceEnd.y.isFinite,
              millimeters.isFinite, (1...5000).contains(millimeters) else { return nil }
        let distance = hypot(referenceEnd.x - referenceStart.x, referenceEnd.y - referenceStart.y)
        guard distance.isFinite, distance >= 0.02 else { return nil }
        let result = millimeters / Double(distance)
        return result.isFinite ? result : nil
    }

    static func calculate(referenceStart: CGPoint, referenceEnd: CGPoint, knee: CGPoint,
                          pedal: CGPoint, referenceMillimeters: Double) -> KopsMeasurement? {
        guard knee.x.isFinite, knee.y.isFinite, pedal.x.isFinite, pedal.y.isFinite,
              let scale = scale(referenceStart: referenceStart, referenceEnd: referenceEnd,
                                millimeters: referenceMillimeters) else { return nil }
        let offset = Double(knee.x - pedal.x) * scale
        guard offset.isFinite else { return nil }
        return KopsMeasurement(offsetMillimeters: offset)
    }
}

struct KopsCalibration {
    let millimetersPerImageWidth: Double
    let facingRight: Bool
}

struct KopsVideoResult: Codable {
    let offsetMillimeters: Double?
    let time: Double?
    let validSamples: Int
    let facingRight: Bool
}

struct KopsVideoTracker {
    let calibration: KopsCalibration
    private(set) var validSamples = 0
    private var forwardPosition: Double?
    private var offset: Double?
    private var time: Double?

    init(calibration: KopsCalibration) {
        self.calibration = calibration
    }

    mutating func add(points: BodyPoints, time: Double) {
        guard let foot = points.foot, time.isFinite, time >= 0 else { return }
        let ankleX = Double(points.ankle.x)
        let footX = Double(foot.x)
        let kneeX = Double(points.knee.x)
        guard ankleX.isFinite, footX.isFinite, kneeX.isFinite else { return }
        let sign = calibration.facingRight ? 1.0 : -1.0
        let position = ankleX * sign
        let difference = (kneeX - (ankleX + footX) / 2) * sign * calibration.millimetersPerImageWidth
        guard difference.isFinite else { return }
        validSamples += 1
        if forwardPosition.map({ position > $0 }) ?? true {
            forwardPosition = position
            offset = difference
            self.time = time
        }
    }

    var result: KopsVideoResult {
        KopsVideoResult(offsetMillimeters: offset, time: time, validSamples: validSamples,
                        facingRight: calibration.facingRight)
    }
}
