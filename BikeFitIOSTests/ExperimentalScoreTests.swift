import XCTest
@testable import BikeFitIOS

final class ExperimentalScoreTests: XCTestCase {
    private let profile = ReferenceProfile(id: UUID(), name: "Prueba", ranges: [
        .knee: AngleRange(minimum: 20, maximum: 40),
        .hip: AngleRange(minimum: 10, maximum: 20)
    ])

    func testScoreWeightsMetricsEquallyAndIncludesRangeBoundaries() {
        let samples = (0..<15).map { index in
            AngleSample(time: Double(index) * 0.2, angles: [
                .knee: index < 12 ? 20 : 50,
                .hip: index < 6 ? 20 : 30
            ])
        }
        let result = VideoAnalysisResult(ranges: [:], validFrames: 15, sampledFrames: 15,
                                         side: "izquierdo", timeline: samples)
        guard case .available(let score) = ExperimentalScore.calculate(result: result, profile: profile) else {
            return XCTFail("Debe calcularse la puntuación con seguimiento suficiente.")
        }
        XCTAssertEqual(score.value, 60, accuracy: 0.001)
        XCTAssertEqual(score.metrics.count, 2)
    }

    func testRejectsInsufficientTrackingOrMissingReferencedMetric() {
        let samples = (0..<11).map { index in
            AngleSample(time: Double(index) * 0.2, angles: [.knee: 30, .hip: 15])
        }
        let lowTracking = VideoAnalysisResult(ranges: [:], validFrames: 11, sampledFrames: 15,
                                              side: "izquierdo", timeline: samples)
        if case .available = ExperimentalScore.calculate(result: lowTracking, profile: profile) {
            XCTFail("No debe calcularse con menos del 80 % de muestras.")
        }
        let missing = (0..<15).map { AngleSample(time: Double($0), angles: [JointAngle.knee: 30]) }
        let noHip = VideoAnalysisResult(ranges: [:], validFrames: 15, sampledFrames: 15,
                                       side: "izquierdo", timeline: missing)
        if case .available = ExperimentalScore.calculate(result: noHip, profile: profile) {
            XCTFail("No debe ignorarse una métrica del perfil sin datos.")
        }
    }

    func testAcceptsExactCoverageThresholdButRejectsShortOrLegacySessions() {
        let samples = (0..<12).map { AngleSample(time: Double($0), angles: [JointAngle.knee: 30, .hip: 15]) }
        let result = VideoAnalysisResult(ranges: [:], validFrames: 12, sampledFrames: 15,
                                         side: "izquierdo", timeline: samples)
        if case .unavailable = ExperimentalScore.calculate(result: result, profile: profile) {
            XCTFail("El 80 % de cobertura debe ser suficiente.")
        }
        let short = VideoAnalysisResult(ranges: [:], validFrames: 12, sampledFrames: 14,
                                        side: "izquierdo", timeline: samples)
        if case .available = ExperimentalScore.calculate(result: short, profile: profile) {
            XCTFail("Una sesión corta no debe recibir puntuación.")
        }
        let legacy = VideoAnalysisResult(ranges: [:], validFrames: 15, sampledFrames: 15, side: "izquierdo")
        if case .available = ExperimentalScore.calculate(result: legacy, profile: profile) {
            XCTFail("No debe puntuarse una sesión sin muestras.")
        }
    }
}
