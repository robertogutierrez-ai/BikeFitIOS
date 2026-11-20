import Charts
import SwiftUI

struct AngleTimelineView: View {
    let samples: [AngleSample]
    @State private var selectedAngle: JointAngle

    init(samples: [AngleSample]) {
        self.samples = samples
        let first = JointAngle.allCases.first { angle in
            samples.contains { $0.angles[angle] != nil }
        }
        _selectedAngle = State(initialValue: first ?? .knee)
    }

    private var availableAngles: [JointAngle] {
        JointAngle.allCases.filter { angle in
            samples.contains { $0.angles[angle] != nil }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Evolución durante el vídeo").font(.headline)
            if availableAngles.isEmpty {
                Text("No hay métricas disponibles para la gráfica.")
            } else {
                Picker("Métrica", selection: $selectedAngle) {
                    ForEach(availableAngles, id: \.self) { angle in
                        Text(angle.rawValue).tag(angle)
                    }
                }
                Chart {
                    ForEach(samples.indices, id: \.self) { index in
                        if let angle = samples[index].angles[selectedAngle] {
                            PointMark(
                                x: .value("Tiempo (s)", samples[index].time),
                                y: .value("Ángulo (°)", angle)
                            )
                        }
                    }
                }
                .chartYScale(domain: 0.0...180.0)
                .chartXAxisLabel("Tiempo del vídeo (s)")
                .chartYAxisLabel("Grados")
                .frame(height: 220)
                Text("Cada punto es una muestra válida del lado seleccionado. Los huecos no representan mediciones; el tiempo es el solicitado al vídeo, aproximadamente cada 0,2 s.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
