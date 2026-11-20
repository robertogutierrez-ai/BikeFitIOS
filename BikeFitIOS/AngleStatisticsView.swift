import SwiftUI

struct AngleStatisticsView: View {
    let samples: [AngleSample]

    var body: some View {
        DisclosureGroup("Estadísticas de las muestras") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(JointAngle.allCases, id: \.self) { angle in
                    if let statistics = AngleStatistics.calculate(for: angle, samples: samples) {
                        VStack(alignment: .leading) {
                            Text(angle.rawValue).font(.subheadline.bold())
                            Text(String(format: "Media %.1f° · variación %.1f° · amplitud %.1f° · %d muestras",
                                        statistics.mean, statistics.standardDeviation, statistics.amplitude, statistics.count))
                                .font(.footnote)
                        }
                    }
                }
                Text("La variación es la desviación estándar de los fotogramas válidos; la amplitud es máximo menos mínimo. No son una puntuación de calidad ni de ajuste y dependen del encuadre y del seguimiento.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
