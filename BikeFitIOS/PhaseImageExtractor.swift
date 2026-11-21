import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum PhaseImageExtractor {
    static func extract(from url: URL, phases: [PedalingPhase]) throws -> [String: Data] {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1280, height: 1280)
        var result: [String: Data] = [:]
        for phase in phases {
            let frame = try generator.copyCGImage(
                at: CMTime(seconds: phase.time, preferredTimescale: 600), actualTime: nil
            )
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                data, UTType.jpeg.identifier as CFString, 1, nil
            ) else { throw ExtractionError.invalidImage }
            CGImageDestinationAddImage(destination, frame, [
                kCGImageDestinationLossyCompressionQuality: 0.85
            ] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { throw ExtractionError.invalidImage }
            result[phase.kind.rawValue] = data as Data
        }
        return result
    }

    private enum ExtractionError: LocalizedError {
        case invalidImage
        var errorDescription: String? { "El fotograma no se pudo convertir a imagen." }
    }
}
