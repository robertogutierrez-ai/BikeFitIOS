import Foundation
import CoreGraphics

enum JointAngle: String, CaseIterable {
    case knee = "Rodilla"
    case hip = "Cadera"
    case elbow = "Codo"
    case shoulder = "Hombro"
}

struct BodyPoints {
    let shoulder: CGPoint
    let elbow: CGPoint
    let wrist: CGPoint
    let hip: CGPoint
    let knee: CGPoint
    let ankle: CGPoint
}

enum AngleCalculator {
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
        let values: [(JointAngle, Double?)] = [
            (.knee, angle(hip, knee, ankle)),
            (.hip, angle(shoulder, hip, knee)),
            (.elbow, angle(shoulder, elbow, wrist)),
            (.shoulder, angle(hip, shoulder, elbow))
        ]
        return Dictionary(uniqueKeysWithValues: values.compactMap { key, value in
            value.map { (key, $0) }
        })
    }
}
