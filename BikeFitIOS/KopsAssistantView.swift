import PhotosUI
import SwiftUI
import UIKit

struct KopsAssistantView: View {
    let onClose: () -> Void
    @State private var selection: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var points: [CGPoint] = []
    @State private var referenceLength = ""
    @State private var measurement: KopsMeasurement?
    @State private var loading = false
    @State private var error: String?

    private let instructions = [
        "Marca un extremo de la referencia.",
        "Marca el otro extremo de la referencia.",
        "Marca el punto de referencia elegido en la rodilla.",
        "Marca el centro del eje del pedal."
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("KOPS manual · experimental").font(.title2.bold())
                Text("Elige una foto lateral con la biela aproximadamente horizontal y el pedal visible. Coloca una referencia de longitud conocida en el mismo plano que la rodilla y el pedal.")
                Text("La cámara debe estar fija, nivelada y perpendicular al plano de la bicicleta. Marca tú mismo los puntos: la app no identifica la anatomía ni detecta la fase de pedaleo.")
                    .foregroundStyle(.secondary)
                PhotosPicker(selection: $selection, matching: .images) {
                    Text(image == nil ? "Seleccionar fotografía" : "Elegir otra fotografía")
                }
                .buttonStyle(.bordered)
                .disabled(loading)
                if loading {
                    ProgressView("Cargando fotografía…")
                }
                if let image = image {
                    Text(points.count < 4 ? instructions[points.count] : "Comprueba los cuatro puntos.")
                    ImagePointMarkingView(
                        image: image, points: $points,
                        accessibilityDescription: "Fotografía lateral. Toca los dos extremos de referencia, la rodilla y el eje del pedal."
                    )
                    .frame(height: 340)
                    Text("Azul: referencia · Naranja: rodilla y eje del pedal")
                        .font(.caption)
                    Button("Deshacer punto") {
                        points.removeLast()
                        measurement = nil
                    }
                    .disabled(points.isEmpty || loading)
                    TextField("Longitud de la referencia en milímetros", text: $referenceLength)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: referenceLength) { _ in measurement = nil }
                    Text("Introduce una longitud entre 1 y 5000 mm.")
                        .font(.footnote)
                    Button("Calcular desplazamiento") { calculate() }
                        .buttonStyle(.borderedProminent)
                        .disabled(points.count != 4 || loading)
                    if let measurement = measurement {
                        Text(String(format: "Rodilla respecto al eje del pedal: %+.1f mm", measurement.offsetMillimeters))
                            .font(.headline)
                        Text("Positivo significa hacia la derecha de la imagen; negativo, hacia la izquierda. No indica por sí solo si la rodilla está adelantada o retrasada.")
                            .font(.footnote)
                    }
                    Text("Estimación 2D no validada: la perspectiva, el plano de referencia, la inclinación de cámara y el marcado pueden producir errores importantes. No es un diagnóstico ni una recomendación de ajuste.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Esta escala solo se usa para la foto actual; no se aplica automáticamente al análisis de vídeo. La foto no se guarda en el historial.")
                        .font(.footnote)
                }
                Button("Volver", action: onClose).disabled(loading)
            }
            .padding()
        }
        .onChange(of: selection) { selected in
            guard let selected = selected, !loading else { return }
            loading = true
            Task {
                do {
                    guard let data = try await selected.loadTransferable(type: Data.self),
                          let loaded = UIImage(data: data), loaded.size.width > 0, loaded.size.height > 0 else {
                        throw ImageError.unavailable
                    }
                    image = loaded
                    points = []
                    measurement = nil
                } catch {
                    self.error = "No se pudo cargar la fotografía: \(error.localizedDescription)"
                }
                selection = nil
                loading = false
            }
        }
        .alert("KOPS manual", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    private func calculate() {
        guard points.count == 4,
              let length = Double(referenceLength.replacingOccurrences(of: ",", with: ".")),
              let result = KopsMeasurement.calculate(
                referenceStart: points[0], referenceEnd: points[1], knee: points[2],
                pedal: points[3], referenceMillimeters: length
              ) else {
            measurement = nil
            error = "Comprueba la longitud y marca una referencia suficientemente larga en la imagen."
            return
        }
        measurement = result
    }

    private enum ImageError: LocalizedError {
        case unavailable

        var errorDescription: String? { "La imagen seleccionada no está disponible." }
    }
}
