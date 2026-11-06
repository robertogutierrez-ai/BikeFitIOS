import AVFoundation
import AVKit
import SwiftUI

struct ContentView: View {
    private enum Screen {
        case home, capture, review, results
    }

    @State private var screen: Screen = .home
    @State private var videoURL: URL?
    @State private var result: VideoAnalysisResult?
    @State private var analysisError: String?
    @State private var isAnalyzing = false
    @State private var analysisTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                switch screen {
                case .home:
                    home
                case .capture:
                    CaptureScreen(onCancel: { screen = .home }, onFinished: { url in
                        videoURL = url
                        screen = .review
                    })
                case .review:
                    if let url = videoURL {
                        review(url: url)
                    }
                case .results:
                    if let result = result {
                        results(result)
                    }
                }
            }
            .navigationTitle("BikeFit")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Asistente de vídeo").font(.title.bold())
                Text("Prepara el rodillo en un lugar estable, despejado y bien iluminado.")
                Text("Coloca el iPhone en un soporte fijo, de lado y perpendicular a la bicicleta.")
                Text("Aleja la cámara hasta que entren la bicicleta y todo el cuerpo, incluidos cabeza, manos y pies, durante toda la pedalada.")
                Text("En la cámara puedes mostrar u ocultar el marco, el centro y la línea inferior de referencia.")
                Text("Graba unos 15 segundos pedaleando con naturalidad. El vídeo se graba sin sonido y se analiza en el dispositivo.")
                Text("Las guías son orientativas: no detectan ni validan automáticamente el encuadre y no se graban en el vídeo.")
                    .foregroundStyle(.secondary)
                Button("Abrir cámara guiada") {
                    screen = .capture
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    private func review(url: URL) -> some View {
        ReviewScreen(
            url: url,
            isAnalyzing: isAnalyzing,
            error: analysisError,
            onAnalyze: { startAnalysis(url) },
            onCancelAnalysis: { analysisTask?.cancel() },
            onRetake: {
                if removeVideo() {
                    analysisError = nil
                    screen = .capture
                }
            },
            onClose: {
                if removeVideo() {
                    analysisError = nil
                    screen = .home
                }
            }
        )
    }

    private func startAnalysis(_ url: URL) {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        analysisError = nil
        analysisTask = Task {
            do {
                let worker = Task.detached(priority: .userInitiated) {
                    try VideoAnalyzer.analyze(url: url)
                }
                let measured = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    worker.cancel()
                }
                try Task.checkCancellation()
                result = measured
                screen = .results
            } catch is CancellationError {
                analysisError = nil
            } catch {
                analysisError = "No se pudo analizar el vídeo: \(error.localizedDescription)"
            }
            isAnalyzing = false
            analysisTask = nil
        }
    }

    private func results(_ result: VideoAnalysisResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Resultados básicos").font(.title2.bold())
                Text("Lado \(result.side): \(result.validFrames) de \(result.sampledFrames) fotogramas válidos.")
                ForEach(JointAngle.allCases, id: \.self) { angle in
                    if let range = result.ranges[angle] {
                        HStack {
                            Text(angle.rawValue)
                            Spacer()
                            Text(String(format: "%.1f° – %.1f°", range.minimum, range.maximum))
                        }
                    }
                }
                Text("Los ángulos siguen la convención de la app Android: una articulación completamente estirada se aproxima a 0°. Los resultados son orientativos, no constituyen un diagnóstico ni una recomendación de ajuste.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Esta primera versión utiliza Apple Vision, no MediaPipe. Los resultados pueden diferir de Android y no se han validado clínicamente.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Volver al vídeo") { screen = .review }
                    .buttonStyle(.borderedProminent)
                Button("Finalizar") {
                    if removeVideo() {
                        self.result = nil
                        screen = .home
                    }
                }
            }
            .padding()
        }
        .alert("No se pudo eliminar el vídeo", isPresented: Binding(
            get: { analysisError != nil },
            set: { if !$0 { analysisError = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(analysisError ?? "")
        }
    }

    private func removeVideo() -> Bool {
        guard let url = videoURL else { return true }
        do {
            try FileManager.default.removeItem(at: url)
            videoURL = nil
            return true
        } catch {
            analysisError = "No se pudo eliminar el vídeo temporal: \(error.localizedDescription)"
            return false
        }
    }
}

private struct CaptureScreen: View {
    @StateObject private var camera = CameraCapture()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showGuides = true
    let onCancel: () -> Void
    let onFinished: (URL) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("De lado: deja espacio alrededor del ciclista y la bicicleta durante toda la pedalada.")
                .font(.subheadline)
                .padding(.horizontal)
            GeometryReader { geometry in
                ZStack {
                    CameraPreview(session: camera.session)
                    if showGuides {
                        FramingGuide()
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .accessibilityLabel(showGuides
                    ? "Vista de cámara con marco, centro y línea inferior de referencia"
                    : "Vista de cámara sin guías")
            }
            .background(.black)
            HStack {
                Text(showGuides
                    ? "Marco: deja margen · Cruz: centro · Línea: referencia inferior"
                    : "Guías ocultas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(showGuides ? "Ocultar guías" : "Mostrar guías") {
                    showGuides.toggle()
                }
                .font(.caption)
            }
            .padding(.horizontal)
            Text(camera.recording ? "Grabando · objetivo: 15 segundos" : "Graba unos 15 segundos · Sin sonido")
                .font(.caption)
            HStack {
                Button("Cancelar") { onCancel() }
                    .disabled(camera.finishing)
                Spacer()
                Button(camera.recording ? "Detener y revisar" : "Iniciar grabación") {
                    if camera.recording {
                        camera.stop()
                    } else {
                        let orientation = UIApplication.shared.connectedScenes
                            .compactMap { $0 as? UIWindowScene }
                            .first { $0.activationState == .foregroundActive }?.interfaceOrientation
                        camera.record(orientation: currentVideoOrientation(orientation))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!camera.ready || camera.finishing)
            }
            .padding(.horizontal)
        }
        .onAppear {
            camera.onFinished = onFinished
            camera.start()
        }
        .onDisappear { camera.shutdown() }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                camera.start()
            } else {
                camera.shutdown()
            }
        }
        .alert("Cámara", isPresented: Binding(
            get: { camera.errorMessage != nil },
            set: { if !$0 { camera.errorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(camera.errorMessage ?? "")
        }
    }
}

private struct ReviewScreen: View {
    @State private var player: AVPlayer
    let isAnalyzing: Bool
    let error: String?
    let onAnalyze: () -> Void
    let onCancelAnalysis: () -> Void
    let onRetake: () -> Void
    let onClose: () -> Void

    init(url: URL, isAnalyzing: Bool, error: String?, onAnalyze: @escaping () -> Void, onCancelAnalysis: @escaping () -> Void, onRetake: @escaping () -> Void, onClose: @escaping () -> Void) {
        _player = State(initialValue: AVPlayer(url: url))
        self.isAnalyzing = isAnalyzing
        self.error = error
        self.onAnalyze = onAnalyze
        self.onCancelAnalysis = onCancelAnalysis
        self.onRetake = onRetake
        self.onClose = onClose
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Revisa el vídeo").font(.title2.bold())
                Text("Comprueba que se vean la bicicleta y el cuerpo completo de lado, incluidos cabeza, manos y pies, durante varias pedaladas.")
                VideoPlayer(player: player)
                    .frame(height: 240)
                if isAnalyzing {
                    ProgressView("Analizando vídeo…")
                    Button("Cancelar análisis", action: onCancelAnalysis)
                } else {
                    if let error = error {
                        Text(error).foregroundStyle(.red)
                    }
                    Button("Analizar vídeo", action: onAnalyze).buttonStyle(.borderedProminent)
                    Button("Repetir grabación", action: onRetake)
                    Button("Cerrar", action: onClose)
                }
            }
            .padding()
        }
        .onDisappear { player.pause() }
    }
}
