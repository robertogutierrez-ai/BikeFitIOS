import Foundation
import CoreGraphics

enum JointAngle: String, CaseIterable, Codable {
    case knee = "Rodilla"
    case hip = "Cadera"
    case elbow = "Codo"
    case shoulder = "Hombro"
    case backInclination = "Inclinación de espalda"
    case thighInclination = "Inclinación de muslo"
    case ankle = "Tobillo"
    case footInclination = "Inclinación del pie"
}

struct BodyPoints {
    let shoulder: CGPoint
    let elbow: CGPoint
    let wrist: CGPoint
    let hip: CGPoint
    let knee: CGPoint
    let ankle: CGPoint
    var foot: CGPoint? = nil
}

enum AngleCalculator {
    static let requiredAngles: [JointAngle] = [.knee, .hip, .elbow, .shoulder]

    static func angle(_ first: CGPoint, _ middle: CGPoint, _ last: CGPoint) -> Double? {
        let ax = middle.x - first.x
        let ay = middle.y - first.y
        let bx = last.x - middle.x
        let by = last.y - middle.y
        let magnitude = hypot(ax, ay) * hypot(bx, by)
        guard magnitude > 0 else { return nil }
        let cosine = max(-1, min(1, (ax * bx + ay * by) / magnitude))
        return Double(acos(cosine)) * 180 / Double.pi
    }

    static func inclination(_ first: CGPoint, _ second: CGPoint) -> Double? {
        let dx = second.x - first.x
        let dy = second.y - first.y
        guard dx.isFinite, dy.isFinite, dx != 0 || dy != 0 else { return nil }
        return Double(atan2(abs(dy), abs(dx))) * 180 / Double.pi
    }

    static func calculate(_ points: BodyPoints, width: CGFloat, height: CGFloat) -> [JointAngle: Double] {
        func pixel(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x * width, y: p.y * height)
        }
        let shoulder = pixel(points.shoulder)
        let elbow = pixel(points.elbow)
        let wrist = pixel(points.wrist)
        let hip = pixel(points.hip)
        let knee = pixel(points.knee)
        let ankle = pixel(points.ankle)
        var values: [(JointAngle, Double?)] = [
            (.knee, angle(hip, knee, ankle)),
            (.hip, angle(shoulder, hip, knee)),
            (.elbow, angle(shoulder, elbow, wrist)),
            (.shoulder, angle(hip, shoulder, elbow)),
            (.backInclination, inclination(shoulder, hip)),
            (.thighInclination, inclination(hip, knee))
        ]
        if let foot = points.foot.map(pixel) {
            values.append((.ankle, angle(knee, ankle, foot)))
            values.append((.footInclination, inclination(ankle, foot)))
        }
        return Dictionary(uniqueKeysWithValues: values.compactMap { key, value in
            value.map { (key, $0) }
        })
    }
}
