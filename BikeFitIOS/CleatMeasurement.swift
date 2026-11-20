import CoreGraphics
import Foundation

struct CleatMeasurement {
    let rotationDegrees: Double
    let lateralRelativeToShoe: Double
    let longitudinalRelativeToShoe: Double

    static func calculate(shoeFront: CGPoint, shoeHeel: CGPoint, cleatFront: CGPoint, cleatHeel: CGPoint) -> CleatMeasurement? {
        let points = [shoeFront, shoeHeel, cleatFront, cleatHeel]
        guard points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }
        let shoeX = shoeFront.x - shoeHeel.x
        let shoeY = shoeFront.y - shoeHeel.y
        let cleatX = cleatFront.x - cleatHeel.x
        let cleatY = cleatFront.y - cleatHeel.y
        let shoeLength = hypot(shoeX, shoeY)
        let cleatLength = hypot(cleatX, cleatY)
        guard shoeLength.isFinite, cleatLength.isFinite, shoeLength >= 0.02, cleatLength >= 0.02 else { return nil }

        var rotation = (atan2(cleatY, cleatX) - atan2(shoeY, shoeX)) * 180 / .pi
        rotation.formTruncatingRemainder(dividingBy: 180)
        if rotation > 90 { rotation -= 180 }
        if rotation < -90 { rotation += 180 }

        let dx = (cleatFront.x + cleatHeel.x - shoeFront.x - shoeHeel.x) / 2
        let dy = (cleatFront.y + cleatHeel.y - shoeFront.y - shoeHeel.y) / 2
        return CleatMeasurement(
            rotationDegrees: Double(rotation),
            lateralRelativeToShoe: Double((-dx * shoeY + dy * shoeX) / (shoeLength * shoeLength)),
            longitudinalRelativeToShoe: Double((dx * shoeX + dy * shoeY) / (shoeLength * shoeLength))
        )
    }
}
