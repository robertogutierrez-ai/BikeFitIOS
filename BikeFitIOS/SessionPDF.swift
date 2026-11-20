import UIKit

enum SessionPDF {
    static func make(result: VideoAnalysisResult, date: Date, aiSummary: String? = nil) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        return renderer.pdfData { context in
            context.beginPage()
            let margin: CGFloat = 40
            let width = bounds.width - 2 * margin
            var y: CGFloat = margin

            func text(_ value: String, font: UIFont) {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.black
                ]
                let storage = NSTextStorage(string: value, attributes: attributes)
                let layout = NSLayoutManager()
                let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
                container.lineFragmentPadding = 0
                layout.addTextContainer(container)
                storage.addLayoutManager(layout)
                layout.ensureLayout(for: container)
                layout.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs)) {
                    rect, _, _, glyphs, _ in
                    if y + rect.height > bounds.height - margin {
                        context.beginPage()
                        y = margin
                    }
                    layout.drawGlyphs(forGlyphRange: glyphs, at: CGPoint(x: margin, y: y - rect.minY))
                    y += ceil(rect.height)
                }
                y += 12
            }

            text("BikeFit · Informe de sesión", font: .boldSystemFont(ofSize: 22))
            text("Fecha: \(DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short))",
                 font: .systemFont(ofSize: 12))
            text("Lado \(result.side): \(result.validFrames) de \(result.sampledFrames) fotogramas válidos.",
                 font: .systemFont(ofSize: 12))
            text("Motor: \((result.engine ?? .vision).rawValue)", font: .systemFont(ofSize: 12))
            if let cycles = result.estimatedCycles {
                text("Ciclos aproximados: \(cycles) (estimación experimental).", font: .systemFont(ofSize: 12))
            }
            text("Rangos medidos", font: .boldSystemFont(ofSize: 15))
            for angle in JointAngle.allCases {
                if let range = result.ranges[angle] {
                    text("\(angle.rawValue): \(String(format: "%.1f° – %.1f°", range.minimum, range.maximum))",
                         font: .systemFont(ofSize: 12))
                    if let samples = result.timeline,
                       let stats = AngleStatistics.calculate(for: angle, samples: samples) {
                        text(String(format: "Media: %.1f° · amplitud: %.1f° · %d muestras",
                                    stats.mean, stats.amplitude, stats.count), font: .systemFont(ofSize: 11))
                    }
                }
            }
            if let kops = result.kops, let offset = kops.offsetMillimeters, let time = kops.time {
                text(String(format: "KOPS experimental: %+.1f mm · %.2f s · %d muestras. Positivo hacia el avance indicado (%@); eje del pedal aproximado.",
                            offset, time, kops.validSamples, kops.facingRight ? "derecha" : "izquierda"),
                     font: .systemFont(ofSize: 11))
            }
            if let aiSummary = aiSummary, !aiSummary.isEmpty {
                text("Resumen generado con IA local · experimental", font: .boldSystemFont(ofSize: 15))
                text(aiSummary, font: .systemFont(ofSize: 11))
                text("La IA puede equivocarse o inventar datos. Contrasta el texto con los valores medidos.",
                     font: .systemFont(ofSize: 11))
            }
            text("Los ángulos articulares se aproximan a 0° con la articulación estirada; las inclinaciones se miden respecto a la horizontal. La inclinación del pie no distingue punta arriba o abajo.",
                 font: .systemFont(ofSize: 11))
            text("Resultados orientativos, no validados clínicamente. No constituyen un diagnóstico ni recomendaciones de ajuste. Los motores y dispositivos pueden dar resultados diferentes.",
                 font: .systemFont(ofSize: 11))
        }
    }
}
