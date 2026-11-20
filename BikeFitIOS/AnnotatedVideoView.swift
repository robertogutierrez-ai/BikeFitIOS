import AVKit
import SwiftUI

struct AnnotatedVideoView: View {
    let url: URL
    let side: String
    let onClose: () -> Void
    @StateObject private var exporter = AnnotatedVideoExport()
    @State private var showingShare = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Vídeo anotado · experimental").font(.title2.bold())
                Text("Se vuelve a analizar cada fotograma en el dispositivo. El proceso puede tardar y utiliza espacio temporal.")
                Text("Se dibuja el lado \(side) cuando Vision detecta una postura completa. Si pierde el seguimiento, ese fotograma no lleva anotaciones. Los ángulos son orientativos, no son un diagnóstico.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("El archivo exportado conserva el audio original si lo hay. Compruébalo antes de compartirlo.")
                    .font(.footnote)
                if exporter.exporting {
                    ProgressView("Creando vídeo anotado · \(Int(exporter.progress * 100)) %",
                                 value: Double(exporter.progress), total: 1)
                    Button(exporter.cancelling ? "Cancelando…" : "Cancelar exportación") {
                        exporter.cancel()
                    }
                    .disabled(exporter.cancelling)
                } else if exporter.finished, let fileURL = exporter.fileURL {
                    AnnotatedVideoPreview(url: fileURL)
                    Button("Compartir vídeo anotado") { showingShare = true }
                        .buttonStyle(.borderedProminent)
                } else if exporter.fileURL != nil {
                    Button("Reintentar eliminar el vídeo temporal") { exporter.removeFile() }
                } else {
                    Button("Crear vídeo anotado") { exporter.start(url: url, sideTitle: side) }
                        .buttonStyle(.borderedProminent)
                }

                Button("Volver a resultados") {
                    if exporter.removeFile() { onClose() }
                }
                .disabled(exporter.exporting)
            }
            .padding()
        }
        .sheet(isPresented: $showingShare) {
            if let fileURL = exporter.fileURL {
                ShareDocument(url: fileURL).ignoresSafeArea()
            }
        }

        private struct AnnotatedVideoPreview: View {
            @State private var player: AVPlayer

            init(url: URL) {
                _player = State(initialValue: AVPlayer(url: url))
            }

            var body: some View {
                VideoPlayer(player: player)
                    .frame(height: 240)
                    .onDisappear { player.pause() }
            }
        }
        .onDisappear {
            if exporter.exporting { exporter.cancel() }
        }
        .alert("Vídeo anotado", isPresented: Binding(
            get: { exporter.errorMessage != nil },
            set: { if !$0 { exporter.errorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(exporter.errorMessage ?? "")
        }
    }
}
