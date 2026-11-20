import CoreGraphics
import CoreVideo
import Foundation
import Vision

struct SilhouetteArea {
    let foregroundPixels: Int
    let width: Int
    let height: Int
    let touchesEdge: Bool

    var fraction: Double { Double(foregroundPixels) / Double(width * height) }
}

struct SilhouetteComparison {
    let firstFraction: Double
    let secondFraction: Double
    let relativeChange: Double
}

enum FrontalSilhouette {
    static func analyze(_ image: CGImage) throws -> SilhouetteArea {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        guard let mask = request.results?.first?.pixelBuffer else { throw AnalysisError.missingMask }
        return try measure(mask: mask)
    }

    static func measure(mask: CVPixelBuffer) throws -> SilhouetteArea {
        guard CVPixelBufferGetPixelFormatType(mask) == kCVPixelFormatType_OneComponent8,
              CVPixelBufferLockBaseAddress(mask, .readOnly) == kCVReturnSuccess else {
            throw AnalysisError.invalidMask
        }
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let stride = CVPixelBufferGetBytesPerRow(mask)
        guard width > 0, height > 0, stride >= width,
              let base = CVPixelBufferGetBaseAddress(mask) else { throw AnalysisError.invalidMask }
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        var count = 0
        var touchesEdge = false
        for y in 0..<height {
            for x in 0..<width where bytes[y * stride + x] >= 128 {
                count += 1
                if x == 0 || y == 0 || x == width - 1 || y == height - 1 {
                    touchesEdge = true
                }
            }
        }
        return SilhouetteArea(foregroundPixels: count, width: width, height: height, touchesEdge: touchesEdge)
    }

    static func compare(_ first: SilhouetteArea, _ second: SilhouetteArea) throws -> SilhouetteComparison {
        guard first.width > 0, first.height > 0,
              first.width == second.width, first.height == second.height else {
            throw AnalysisError.incompatibleFrames
        }
        guard first.foregroundPixels > 0, second.foregroundPixels > 0 else { throw AnalysisError.noPerson }
        guard !first.touchesEdge, !second.touchesEdge else { throw AnalysisError.clippedPerson }
        let a = first.fraction
        let b = second.fraction
        return SilhouetteComparison(firstFraction: a, secondFraction: b, relativeChange: (b - a) / a * 100)
    }

    enum AnalysisError: LocalizedError {
        case missingMask, invalidMask, incompatibleFrames, noPerson, clippedPerson

        var errorDescription: String? {
            switch self {
            case .missingMask: return "No se pudo obtener la silueta."
            case .invalidMask: return "La máscara de silueta no tiene un formato válido."
            case .incompatibleFrames: return "Los fotogramas tienen dimensiones diferentes."
            case .noPerson: return "No se detectó una persona en ambas imágenes."
            case .clippedPerson: return "La silueta alcanza el borde; comprueba que la persona aparezca completa."
            }
        }
    }
}
