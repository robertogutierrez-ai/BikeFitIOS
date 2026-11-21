import Foundation

struct PedalingDetector {
    private enum Phase {
        case flexed, extended
    }

    private var phase: Phase?
    private var lastTime: Double?
    private var lastPhaseChange: Double?
    private var lastCycle: Double?
    private(set) var cycles = 0

    mutating func add(kneeAngle: Double, time: Double) throws {
        guard kneeAngle.isFinite, time.isFinite, time >= 0 else { throw SampleError.invalidSample }
        if let previous = lastTime {
            guard time > previous else { throw SampleError.invalidSample }
            if time - previous > 1.5 {
                phase = nil
                lastPhaseChange = nil
            }
        }
        lastTime = time
        let next: Phase?
        if kneeAngle > 90 {
            next = .flexed
        } else if kneeAngle < 70 {
            next = .extended
        } else {
            next = nil
        }
        guard let next = next, next != phase else { return }
        if let last = lastPhaseChange, time - last < 0.12 { return }
        if phase == .flexed && next == .extended,
           lastCycle.map({ time - $0 >= 0.25 }) ?? true {
            cycles += 1
            lastCycle = time
        }
        phase = next
        lastPhaseChange = time
    }

    private enum SampleError: LocalizedError {
        case invalidSample

        var errorDescription: String? {
            "La muestra de rodilla o su instante no son válidos."
        }
    }
}

struct PedalingMotion {
    private var samples: [(time: Double, knee: Double)] = []

    mutating func add(kneeAngle: Double, time: Double) {
        samples.append((time, kneeAngle))
        samples.removeAll { time - $0.time > 1.5 }
    }

    mutating func reset() {
        samples.removeAll()
    }

    var detected: Bool {
        guard samples.count >= 3, let first = samples.first, let last = samples.last,
              last.time - first.time >= 0.4,
              let minimum = samples.map(\.knee).min(),
              let maximum = samples.map(\.knee).max() else { return false }
        return maximum - minimum >= 10
    }
}
