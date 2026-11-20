import CoreGraphics

enum FrontalKneeMeasurement {
    static func separation(knee: CGPoint, ankle: CGPoint) -> Double? {
        guard knee.x.isFinite, knee.y.isFinite, ankle.x.isFinite, ankle.y.isFinite,
              (0...1).contains(knee.x), (0...1).contains(knee.y),
              (0...1).contains(ankle.x), (0...1).contains(ankle.y) else { return nil }
        return Double(abs(knee.x - ankle.x)) * 100
    }
}
