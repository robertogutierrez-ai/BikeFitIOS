import AVFoundation
import SwiftUI
import UIKit

struct KopsVideoCalibrationView: View {
    let url: URL
    let onStart: (KopsCalibration) -> Void
    let onCancel: () -> Void
    @State private var duration: Double?
    @State private var requestedTime = 0.0
    @State private var frameTime: Double?
    @State private var image: UIImage?
    @State private var points: [CGPoint] = []
    @State private var length = ""
    @State private var direction: Direction = .unspecified
    @State private var loading = false
    @State private var error: String?

    private enum Direction: String, CaseIterable {
        case unspecified = "Seleccionar"
        case right = "Hacia la derecha"
        case left = "Hacia la izquierda"
    }

    init(url: URL, onStart: @escaping (KopsCalibration) -> Void, onCancel: @escaping () -> Void) {
        self.url = url
        self.onStart = onStart
        self.onCancel = onCancel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Calibrar KOPS en vídeo · experimental").font(.title2.bold())
                Text("Antes de grabar, coloca una referencia de longitud conocida en el mismo plano que la rodilla y el pedal. La cámara debe permanecer fija, nivelada y sin cambios de zoom durante todo el vídeo.")
                if let duration = duration {
                    Slider(value: $requestedTime, in: 0...(duration - min(duration * 0.5, 0.05)))
                        .disabled(loading)
                    Text(String(format: "Instante solicitado: %.1f s", requestedTime))
                    Button("Mostrar fotograma") { loadFrame() }
                        .buttonStyle(.bordered)
                        .disabled(loading)
                }
                if loading { ProgressView("Preparando fotograma…") }
                if let image = image, let frameTime = frameTime {
                    Text(String(format: "Fotograma de referencia: %.2f s", frameTime))
                    Text(points.count < 2 ? "Marca los dos extremos de la referencia." : "Comprueba los extremos de la referencia.")
                    ImagePointMarkingView(
                        image: image, points: $points,
                        accessibilityDescription: "Fotograma del vídeo. Marca los dos extremos de la referencia.",
                        pointLimit: 2
                    )
                    .frame(height: 340)
                    Button("Deshacer punto") { points.removeLast() }
                        .disabled(points.isEmpty || loading)
                    TextField("Longitud de la referencia en milímetros", text: $length)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    Text("Introduce una longitud entre 1 y 5000 mm.")
                        .font(.footnote)
                    Picker("Dirección de avance en la imagen", selection: $direction) {
                        ForEach(Direction.allCases, id: \.self) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                    Text("MediaPipe estima el eje del pedal como el punto medio entre tobillo y punta, no lo detecta. Se utiliza el fotograma muestreado con el tobillo más adelantado del lado seleccionado.")
                        .font(.footnote)
                    Text("La perspectiva, el marcado, la fase y el seguimiento pueden causar errores importantes. No es un diagnóstico ni una recomendación de ajuste.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Analizar vídeo con KOPS") { start() }
                        .buttonStyle(.borderedProminent)
                        .disabled(points.count != 2 || direction == .unspecified || loading)
                }
                Button("Volver al vídeo", action: onCancel).disabled(loading)
            }
            .padding()
        }
        .task {
            do {
                let value = try await AVURLAsset(url: url).load(.duration).seconds
                guard value.isFinite, value > 0 else { throw CalibrationError.invalidVideo }
                duration = value
            } catch {
                self.error = "No se pudo leer el vídeo: \(error.localizedDescription)"
            }
        }
        .alert("Calibración KOPS", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    private func loadFrame() {
        loading = true
        let time = requestedTime
        let url = url
        Task {
            do {
                let frame = try await Task.detached(priority: .userInitiated) {
                    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                    generator.appliesPreferredTrackTransform = true
                    generator.maximumSize = CGSize(width: 1280, height: 1280)
                    var actual = CMTime.invalid
                    let image = try generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600),
                                                          actualTime: &actual)
                    guard actual.seconds.isFinite else { throw CalibrationError.invalidVideo }
                    return (image, actual.seconds)
                }.value
                image = UIImage(cgImage: frame.0)
                frameTime = frame.1
                points = []
            } catch {
                self.error = "No se pudo extraer el fotograma: \(error.localizedDescription)"
            }
            loading = false
        }
    }

    private func start() {
        guard points.count == 2, direction != .unspecified,
              let millimeters = Double(length.replacingOccurrences(of: ",", with: ".")),
              let scale = KopsMeasurement.scale(referenceStart: points[0], referenceEnd: points[1],
                                                millimeters: millimeters) else {
            error = "Comprueba la longitud y marca una referencia suficientemente larga."
            return
        }
        onStart(KopsCalibration(millimetersPerImageWidth: scale, facingRight: direction == .right))
    }

    private enum CalibrationError: LocalizedError {
        case invalidVideo
        var errorDescription: String? { "El vídeo no contiene un instante válido." }
    }
}
