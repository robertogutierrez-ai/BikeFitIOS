import SwiftUI

struct ExperimentalScoreView: View {
    let result: VideoAnalysisResult
    let profile: ReferenceProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Coincidencia experimental con referencias").font(.headline)
            if let profile = profile {
                switch ExperimentalScore.calculate(result: result, profile: profile) {
                case .available(let score):
                    Text(String(format: "%.0f / 100", score.value)).font(.title2.bold())
                    Text("Perfil actual: \(profile.name)")
                    ForEach(score.metrics, id: \.angle) { metric in
                        Text("\(metric.angle.rawValue): \(metric.inRange) de \(metric.measured) muestras en el rango indicado.")
                            .font(.footnote)
                    }
                case .unavailable(let reason):
                    Text("No disponible: \(reason)").font(.footnote)
                }
            } else {
                Text("Activa un perfil con tus propias referencias para calcularla.").font(.footnote)
            }
            Text("Media del porcentaje de muestras dentro de cada rango del perfil, con igual peso para cada métrica. Exige 15 muestras y al menos el 80 % de seguimiento para cada referencia. Estos mínimos son orientativos, no garantizan fiabilidad. No es una puntuación clínica ni indica el ajuste óptimo.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
