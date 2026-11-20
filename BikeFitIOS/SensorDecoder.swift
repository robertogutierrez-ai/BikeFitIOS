import Foundation

enum SensorDecoder {
    struct CrankSample {
        let revolutions: UInt16
        let eventTime: UInt16
    }

    enum PacketError: LocalizedError {
        case truncated
        var errorDescription: String? { "El sensor ha enviado una medición incompleta." }
    }

    static func power(_ data: Data) throws -> Int {
        let bytes = [UInt8](data)
        guard bytes.count >= 4 else { throw PacketError.truncated }
        return Int(Int16(bitPattern: uint16(bytes, offset: 2)))
    }

    static func heartRate(_ data: Data) throws -> Int {
        let bytes = [UInt8](data)
        guard let flags = bytes.first else { throw PacketError.truncated }
        if flags & 1 != 0 {
            guard bytes.count >= 3 else { throw PacketError.truncated }
            return Int(uint16(bytes, offset: 1))
        }
        guard bytes.count >= 2 else { throw PacketError.truncated }
        return Int(bytes[1])
    }

    static func crank(_ data: Data) throws -> CrankSample? {
        let bytes = [UInt8](data)
        guard let flags = bytes.first else { throw PacketError.truncated }
        let hasWheel = flags & 1 != 0
        let hasCrank = flags & 2 != 0
        let offset = 1 + (hasWheel ? 6 : 0)
        guard bytes.count >= offset else { throw PacketError.truncated }
        guard hasCrank else { return nil }
        guard bytes.count >= offset + 4 else { throw PacketError.truncated }
        return CrankSample(revolutions: uint16(bytes, offset: offset), eventTime: uint16(bytes, offset: offset + 2))
    }

    static func cadence(previous: CrankSample, current: CrankSample) -> Double? {
        let revolutions = current.revolutions &- previous.revolutions
        let ticks = current.eventTime &- previous.eventTime
        guard revolutions > 0, ticks > 0 else { return nil }
        let rpm = Double(revolutions) * 60 * 1024 / Double(ticks)
        return rpm.isFinite && rpm <= 300 ? rpm : nil
    }

    private static func uint16(_ bytes: [UInt8], offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }
}
