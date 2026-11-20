import UIKit

enum SessionPDF {
    static func make(result: VideoAnalysisResult, date: Date) -> Data {
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
                let attributed = NSAttributedString(string: value, attributes: attributes)
                let size = attributed.boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil
                )
                attributed.draw(in: CGRect(x: margin, y: y, width: width, height: ceil(size.height) + 2))
                y += ceil(size.height) + 12
            }

            text("BikeFit · Informe de sesión", font: .boldSystemFont(ofSize: 22))
            text("Fecha: \(DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short))",
                 font: .systemFont(ofSize: 12))
            text("Lado \(result.side): \(result.validFrames) de \(result.sampledFrames) fotogramas válidos.",
                 font: .systemFont(ofSize: 12))
            text("Motor: \((result.engine ?? .vision).rawValue)", font: .systemFont(ofSize: 12))
            text("Rangos medidos", font: .boldSystemFont(ofSize: 15))
            for angle in JointAngle.allCases {
                if let range = result.ranges[angle] {
                    text("\(angle.rawValue): \(String(format: "%.1f° – %.1f°", range.minimum, range.maximum))",
                         font: .systemFont(ofSize: 12))
                }
            }
            text("Los ángulos articulares se aproximan a 0° con la articulación estirada; las inclinaciones se miden respecto a la horizontal. La inclinación del pie no distingue punta arriba o abajo.",
                 font: .systemFont(ofSize: 11))
            text("Resultados orientativos, no validados clínicamente. No constituyen un diagnóstico ni recomendaciones de ajuste. Los motores y dispositivos pueden dar resultados diferentes.",
                 font: .systemFont(ofSize: 11))
        }
    }
}
