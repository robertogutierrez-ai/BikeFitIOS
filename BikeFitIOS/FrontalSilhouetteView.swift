import AVFoundation
import SwiftUI
import UIKit

struct FrontalSilhouetteView: View {
    let url: URL
    let onClose: () -> Void
    @State private var duration: Double?
    @State private var time = 0.0
    @State private var first: Frame?
    @State private var second: Frame?
    @State private var result: SilhouetteComparison?
    @State private var working = false
    @State private var error: String?

    private struct Frame {
        let image: CGImage
        let time: Double
    }

    init(url: URL, onClose: @escaping () -> Void) {
        self.url = url
        self.onClose = onClose
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Comparar siluetas · experimental").font(.title2.bold())
                Text("Usa un vídeo frontal con la cámara fija y sin cambios de zoom. Selecciona dos fotogramas con la persona completa en posturas A y B.")
                Text("Se compara la proporción de imagen ocupada por la silueta detectada. No se calcula CdA, área real ni ahorro de potencia.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let duration = duration {
                    Slider(value: $time, in: 0...(duration - min(duration * 0.5, 0.05)))
                        .disabled(working)
                    Text(String(format: "Instante solicitado: %.1f s", time))
                    HStack {
                        Button("Elegir postura A") { capture(first: true) }
                        Button("Elegir postura B") { capture(first: false) }
                    }
                    .disabled(working)
                }
                if working { ProgressView("Procesando…") }
                if let first = first { frameView("Postura A", frame: first) }
                if let second = second { frameView("Postura B", frame: second) }
                if first != nil && second != nil {
                    Button("Comparar siluetas") { compare() }
                        .buttonStyle(.borderedProminent)
                        .disabled(working)
                }
                if let result = result {
                    Text(String(format: "A: %.1f %% · B: %.1f %% de la imagen",
                                result.firstFraction * 100, result.secondFraction * 100))
                    Text(String(format: "Cambio relativo de silueta: %+.1f %%", result.relativeChange))
                        .font(.headline)
                    Text("Es una comparación visual experimental: la segmentación, la ropa, el encuadre y la postura pueden alterar el resultado. No mide la resistencia aerodinámica ni recomienda ajustes.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button("Volver al vídeo", action: onClose).disabled(working)
            }
            .padding()
        }
        .task {
            do {
                let value = try await AVURLAsset(url: url).load(.duration).seconds
                guard value.isFinite, value > 0 else { throw FrameError.invalidVideo }
                duration = value
            } catch {
                self.error = "No se pudo leer el vídeo: \(error.localizedDescription)"
            }
        }
        .alert("Comparación de siluetas", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    private func frameView(_ title: String, frame: Frame) -> some View {
        VStack(alignment: .leading) {
            Text(String(format: "%@ · %.2f s", title, frame.time))
            Image(decorative: frame.image, scale: 1)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 180)
                .accessibilityLabel(title)
        }
    }

    private func capture(first isFirst: Bool) {
        working = true
        let selected = time
        let url = url
        Task {
            do {
                let frame = try await Task.detached(priority: .userInitiated) {
                    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                    generator.appliesPreferredTrackTransform = true
                    generator.maximumSize = CGSize(width: 1280, height: 1280)
                    var actual = CMTime.invalid
                    let image = try generator.copyCGImage(at: CMTime(seconds: selected, preferredTimescale: 600),
                                                          actualTime: &actual)
                    guard actual.seconds.isFinite else { throw FrameError.invalidVideo }
                    return Frame(image: image, time: actual.seconds)
                }.value
                if isFirst { first = frame } else { second = frame }
                result = nil
            } catch {
                self.error = "No se pudo obtener el fotograma: \(error.localizedDescription)"
            }
            working = false
        }
    }

    private func compare() {
        guard let first = first, let second = second else { return }
        working = true
        Task {
            do {
                result = try await Task.detached(priority: .userInitiated) {
                    guard first.image.width == second.image.width, first.image.height == second.image.height else {
                        throw FrontalSilhouette.AnalysisError.incompatibleFrames
                    }
                    return try FrontalSilhouette.compare(
                        FrontalSilhouette.analyze(first.image),
                        FrontalSilhouette.analyze(second.image)
                    )
                }.value
            } catch {
                result = nil
                self.error = "No se pudieron comparar las siluetas: \(error.localizedDescription)"
            }
            working = false
        }
    }

    private enum FrameError: LocalizedError {
        case invalidVideo
        var errorDescription: String? { "El vídeo no contiene un instante válido." }
    }
}
