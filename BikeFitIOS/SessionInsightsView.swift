import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

struct SessionInsightsView: View {
    let result: VideoAnalysisResult
    let date: Date
    @State private var summary: String?
    @State private var generating = false
    @State private var error: String?
    @State private var task: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let summary = summary {
                Text("Resumen generado con IA local · experimental").font(.headline)
                Text(summary)
                Text("La IA puede equivocarse o inventar datos. Contrasta el texto con los valores medidos; no es un diagnóstico ni una recomendación de ajuste.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let reason = unavailableReason {
                Text(reason).font(.footnote).foregroundStyle(.secondary)
            } else {
                Button(generating ? "Generando resumen…" : "Generar resumen con IA local") { generate() }
                    .disabled(generating)
            }
            SessionExportButton(result: result, date: date, aiSummary: summary)
        }
        .onDisappear { task?.cancel() }
        .alert("Resumen con IA", isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private var unavailableReason: String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return nil }
            return "IA local no disponible: comprueba la compatibilidad y que Apple Intelligence esté activada y preparada."
        }
        #endif
        return "IA local requiere iOS 26, un dispositivo compatible y una app compilada con Xcode 26 o posterior."
    }

    private func generate() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            generating = true
            summary = nil
            task = Task {
                do {
                    let model = LanguageModelSession(instructions: """
                    Resume datos de medición de forma descriptiva y breve en español. No hagas diagnósticos,
                    no propongas ajustes, no evalúes si la postura es correcta y no inventes datos.
                    """)
                    let ranges = JointAngle.allCases.compactMap { angle -> String? in
                        guard let range = result.ranges[angle] else { return nil }
                        return "\(angle.rawValue): \(String(format: "%.1f a %.1f grados", range.minimum, range.maximum))"
                    }.joined(separator: "; ")
                    let response = try await model.respond(to: "Describe en dos frases estos datos experimentales: lado \(result.side), \(result.validFrames) de \(result.sampledFrames) fotogramas válidos; \(ranges).")
                    try Task.checkCancellation()
                    let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { throw SummaryError.empty }
                    summary = text
                } catch is CancellationError {
                } catch {
                    self.error = "No se pudo generar el resumen: \(error.localizedDescription)"
                }
                generating = false
                task = nil
            }
        }
        #endif
    }

    private enum SummaryError: LocalizedError {
        case empty
        var errorDescription: String? { "El modelo no ha generado ningún texto." }
    }
}
