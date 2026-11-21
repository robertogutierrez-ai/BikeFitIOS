import AVFoundation
import AVKit
import PhotosUI
import SwiftUI

struct ContentView: View {
    private enum Screen {
        case home, capture, live, frontal, silhouettes, sensors, arMeasure, review, results, annotatedVideo, cleats, kops, kopsVideo, history, profiles
    }

    @State private var screen: Screen = .home
    @State private var liveEngine: AnalysisEngine = .vision
    @State private var videoURL: URL?
    @State private var result: VideoAnalysisResult?
    @State private var analysisError: String?
    @State private var isAnalyzing = false
    @State private var analysisTask: Task<Void, Never>?
    @State private var selectedVideo: PhotosPickerItem?
    @State private var isImporting = false
    @State private var importError: String?
    @State private var savedResult = false
    @State private var savedSession: SavedSession?
    @State private var writingPhaseImages = false
    @State private var activeProfile: ReferenceProfile?
    @State private var analysisID: UUID?
    @State private var analysisProgress: Double?
    @State private var isCancellingAnalysis = false

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
                case .live:
                    LiveAnalysisView(engine: liveEngine, onClose: { screen = .home }, onRecorded: { url in
                        videoURL = url
                        result = nil
                        screen = .review
                    })
                case .frontal:
                    LiveAnalysisView(mode: .frontal, onClose: { screen = .home })
                case .silhouettes:
                    if let url = videoURL {
                        FrontalSilhouetteView(url: url, onClose: { screen = .review })
                    }
                case .sensors:
                    BluetoothSensorsView(onClose: { screen = .home })
                case .arMeasure:
                    ARMeasurementView(onClose: { screen = .home })
                case .review:
                    if let url = videoURL {
                        review(url: url)
                    }
                case .results:
                    if let result = result {
                        results(result)
                    }
                case .annotatedVideo:
                    if let url = videoURL, let result = result {
                        AnnotatedVideoView(url: url, side: result.side, engine: result.engine ?? .vision, onClose: { screen = .results })
                    }
                case .cleats:
                    CleatAssistantView(onClose: { screen = .home })
                case .kops:
                    KopsAssistantView(onClose: { screen = .home })
                case .kopsVideo:
                    if let url = videoURL {
                        KopsVideoCalibrationView(url: url) { calibration in
                            screen = .review
                            startAnalysis(url, engine: .mediaPipe, calibration: calibration)
                        } onCancel: {
                            screen = .review
                        }
                    }
                case .history:
                    SessionHistoryView(onClose: { screen = .home })
                case .profiles:
                    ReferenceProfilesView(onClose: { screen = .home })
                }
            }
            .navigationTitle("BikeFit")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: selectedVideo) { selection in
            guard let selection = selection, !isImporting else { return }
            isImporting = true
            Task {
                do {
                    guard let video = try await selection.loadTransferable(type: ImportedVideo.self) else {
                        throw VideoImportError.unavailable
                    }
                    videoURL = video.url
                    result = nil
                    analysisError = nil
                    screen = .review
                } catch {
                    importError = "No se pudo importar el vídeo: \(error.localizedDescription)"
                }
                selectedVideo = nil
                isImporting = false
            }
        }
        .alert("Importar vídeo", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(importError ?? "")
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
                .disabled(isImporting)
                Button("Análisis en directo (experimental)") {
                    liveEngine = .vision
                    screen = .live
                }
                .buttonStyle(.bordered)
                .disabled(isImporting)
                Button("Análisis en directo con MediaPipe (experimental)") {
                    liveEngine = .mediaPipe
                    screen = .live
                }
                .buttonStyle(.bordered)
                .disabled(isImporting)
                Button("Análisis frontal (experimental)") {
                    screen = .frontal
                }
                .buttonStyle(.bordered)
                .disabled(isImporting)
                PhotosPicker(selection: $selectedVideo, matching: .videos) {
                    Text("Analizar vídeo de la fototeca")
                }
                .buttonStyle(.bordered)
                .disabled(isImporting)
                if isImporting {
                    ProgressView("Importando vídeo…")
                    Text("Si el vídeo está en iCloud, puede tardar en descargarse.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Divider()
                Text("Asistente de calas").font(.title2.bold())
                Text("Fotografía cada suela y marca manualmente los ejes de la zapatilla y de la cala.")
                Button("Abrir asistente de calas") {
                    screen = .cleats
                }
                .buttonStyle(.bordered)
                .disabled(isImporting)
                Divider()
                Text("Medición KOPS manual").font(.title2.bold())
                Text("Usa una fotografía lateral y una referencia de longitud conocida.")
                Button("Abrir asistente KOPS") { screen = .kops }
                    .buttonStyle(.bordered)
                    .disabled(isImporting)
                Divider()
                Text("Medición AR").font(.title2.bold())
                Button("Medir dos puntos con AR") { screen = .arMeasure }
                    .buttonStyle(.bordered)
                    .disabled(isImporting)
                Divider()
                Text("Sensores Bluetooth").font(.title2.bold())
                Button("Conectar sensor") { screen = .sensors }
                    .buttonStyle(.bordered)
                    .disabled(isImporting)
                Divider()
                Text("Sesiones guardadas").font(.title2.bold())
                Text("Consulta o elimina los resultados que hayas guardado en este dispositivo.")
                Button("Ver historial de sesiones") { screen = .history }
                    .buttonStyle(.bordered)
                    .disabled(isImporting)
                Divider()
                Text("Perfiles y referencias").font(.title2.bold())
                Text("Crea perfiles con tus propias referencias orientativas para consultar junto a los resultados.")
                Button("Gestionar perfiles") { screen = .profiles }
                    .buttonStyle(.bordered)
                    .disabled(isImporting)
            }
            .padding()
        }
    }

    private func review(url: URL) -> some View {
        ReviewScreen(
            url: url,
            isAnalyzing: isAnalyzing,
            progress: analysisProgress,
            isCancelling: isCancellingAnalysis,
            error: analysisError,
            onAnalyze: { startAnalysis(url, engine: .vision) },
            onAnalyzeMediaPipe: { startAnalysis(url, engine: .mediaPipe) },
            onAnalyzeKops: { screen = .kopsVideo },
            onCompareSilhouettes: { screen = .silhouettes },
            onCancelAnalysis: {
                isCancellingAnalysis = true
                analysisTask?.cancel()
            },
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

    private func startAnalysis(_ url: URL, engine: AnalysisEngine, calibration: KopsCalibration? = nil) {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        isCancellingAnalysis = false
        analysisProgress = nil
        let id = UUID()
        analysisID = id
        analysisError = nil
        analysisTask = Task {
            do {
                let worker = Task.detached(priority: .userInitiated) {
                    try VideoAnalyzer.analyze(url: url, engine: engine, kopsCalibration: calibration) { progress in
                        DispatchQueue.main.async {
                            guard analysisID == id, isAnalyzing, !isCancellingAnalysis else { return }
                            analysisProgress = progress
                        }
                    }
                }
                let measured = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    worker.cancel()
                }
                try Task.checkCancellation()
                result = measured
                savedResult = false
                savedSession = nil
                screen = .results
            } catch is CancellationError {
                analysisError = nil
            } catch {
                if Task.isCancelled {
                    analysisError = nil
                } else {
                    analysisError = "No se pudo analizar el vídeo: \(error.localizedDescription)"
                }
            }
            isAnalyzing = false
            isCancellingAnalysis = false
            analysisID = nil
            analysisProgress = nil
            analysisTask = nil
        }
    }

    private func results(_ result: VideoAnalysisResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Resultados básicos").font(.title2.bold())
                Text("Motor: \((result.engine ?? .vision).rawValue)")
                Text("Lado \(result.side): \(result.validFrames) de \(result.sampledFrames) fotogramas válidos.")
                if result.sampledFrames > 0 {
                    Text(String(format: "Seguimiento válido: %.0f %%", 100.0 * Double(result.validFrames) / Double(result.sampledFrames)))
                }
                if let cycles = result.estimatedCycles {
                    Text("Ciclos aproximados: \(cycles)")
                    Text("Estimación experimental basada en la rodilla. La detección puede omitir ciclos y no mide la calidad del ajuste.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let spread = result.kneeHorizontalSpreadPercent {
                    Text(String(format: "Dispersión horizontal de rodilla: %.1f %% del ancho de imagen", spread))
                        .font(.footnote)
                    Text("Desviación estándar de los puntos 2D observados; depende del encuadre y no mide una oscilación clínica.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let phases = result.phases, !phases.isEmpty {
                    ForEach(phases, id: \.kind.rawValue) { phase in
                        Text(String(format: "%@: %.2f s", phase.kind.title, phase.time))
                    }
                    Text("Extremos 2D aproximados, no fases anatómicas verificadas; el punto adelantado depende de la dirección estimada o calibrada.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if result.engine == .mediaPipe, let samples = result.timeline {
                    let footCount = samples.filter { $0.angles[.footInclination] != nil }.count
                    Text("Pie detectado: \(footCount) de \(result.sampledFrames) fotogramas muestreados.")
                        .font(.footnote)
                    if footCount == 0 {
                        Text("No hay mediciones del pie: comprueba que la punta sea visible.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let kops = result.kops {
                        Text("KOPS en vídeo · experimental").font(.headline)
                        if let offset = kops.offsetMillimeters, let time = kops.time {
                            Text(String(format: "Desplazamiento estimado: %+.1f mm · instante %.2f s", offset, time))
                            Text("Positivo hacia el avance indicado (\(kops.facingRight ? "derecha" : "izquierda") de la imagen). Calculado en el tobillo más adelantado entre \(kops.validSamples) muestras con punta visible; el eje del pedal se aproxima entre tobillo y punta.")
                                .font(.footnote)
                        } else {
                            Text("No disponible: no se detectó una punta de pie válida en el lado seleccionado.")
                                .font(.footnote)
                        }
                        Text("Medición 2D no validada: depende de la calibración, perspectiva y seguimiento. No es un diagnóstico ni recomienda ajustes.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(JointAngle.allCases, id: \.self) { angle in
                    if let range = result.ranges[angle] {
                        HStack {
                            Text(angle.rawValue)
                            Spacer()
                            Text(String(format: "%.1f° – %.1f°", range.minimum, range.maximum))
                        }
                        if let reference = activeProfile?.ranges[angle] {
                            Text("Referencia indicada: \(String(format: "%.1f° – %.1f°", reference.minimum, reference.maximum))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let samples = result.timeline, !samples.isEmpty {
                    AngleTimelineView(samples: samples)
                    AngleStatisticsView(samples: samples)
                }
                ExperimentalScoreView(result: result, profile: activeProfile)
                if let profile = activeProfile {
                    Text("Referencias actuales del perfil «\(profile.name)», introducidas por el usuario. No son un diagnóstico ni objetivos validados.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text("En los ángulos articulares una articulación estirada se aproxima a 0°. Las inclinaciones se miden respecto a la horizontal; la del pie no distingue punta arriba o abajo. El ángulo del tronco depende de la dirección en la imagen. Los resultados son orientativos, no constituyen un diagnóstico ni una recomendación de ajuste.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Los resultados pueden diferir de Android y no se han validado clínicamente.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Puedes guardar estos resultados en el historial local; el vídeo no se guarda.")
                    .font(.footnote)
                Button(savedResult ? "Resultados guardados" : "Guardar resultados") {
                    do {
                        savedSession = try SessionHistoryStore.standard().save(result)
                        savedResult = true
                    } catch {
                        analysisError = "No se pudieron guardar los resultados: \(error.localizedDescription)"
                    }
                }
                .disabled(savedResult)
                if let session = savedSession, let url = videoURL {
                    PhaseImagesView(session: session, videoURL: url, onBusyChange: { writingPhaseImages = $0 })
                }
                SessionInsightsView(result: result, date: Date())
                Button("Crear vídeo anotado (experimental)") { screen = .annotatedVideo }
                    .buttonStyle(.bordered)
                    .disabled(writingPhaseImages)
                Button("Volver al vídeo") { screen = .review }
                    .buttonStyle(.borderedProminent)
                    .disabled(writingPhaseImages)
                Button("Finalizar") {
                    if removeVideo() {
                        self.result = nil
                        screen = .home
                    }
                }
                .disabled(writingPhaseImages)
            }
            .padding()
        }
        .onAppear {
            do {
                activeProfile = try ReferenceProfileStore().active()
            } catch {
                activeProfile = nil
                analysisError = "No se pudo leer el perfil activo: \(error.localizedDescription)"
            }
        }
        .alert("Resultados", isPresented: Binding(
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

private enum VideoImportError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "No se pudo obtener el archivo seleccionado."
    }
}

private struct CaptureScreen: View {
    @StateObject private var camera = CameraCapture()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showGuides = true
    @AppStorage("bikefit.capture.voice") private var voiceEnabled = false
    @AppStorage("bikefit.capture.haptics") private var hapticsEnabled = false
    @State private var speech = AVSpeechSynthesizer()
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
                Toggle("Avisos por voz", isOn: $voiceEnabled)
                Toggle("Vibración", isOn: $hapticsEnabled)
            }
            .font(.caption)
            .padding(.horizontal)
            if camera.starting {
                ProgressView("Iniciando cámara…")
            } else if !camera.ready {
                Button("Reintentar cámara") { camera.start() }
                    .disabled(camera.finishing)
            }
            Button(camera.position == .back ? "Usar cámara frontal" : "Usar cámara trasera") {
                camera.switchCamera()
            }
            .disabled(!camera.canSwitchCamera)
            HStack {
                Button("Cancelar") { onCancel() }
                    .disabled(camera.finishing)
                Spacer()
                Button(camera.recording ? "Detener y revisar" : "Iniciar grabación") {
                    if camera.recording {
                        camera.stop()
                        announce("Finalizando grabación.")
                    } else {
                        let orientation = UIApplication.shared.connectedScenes
                            .compactMap { $0 as? UIWindowScene }
                            .first { $0.activationState == .foregroundActive }?.interfaceOrientation
                        camera.record(orientation: currentVideoOrientation(orientation))
                        if camera.recording { announce("Grabación iniciada.") }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!camera.ready || camera.finishing || camera.switching)
            }
            .padding(.horizontal)
        }
        .onAppear {
            camera.onFinished = onFinished
            camera.start()
        }
        .onDisappear {
            camera.shutdown()
            speech.stopSpeaking(at: .immediate)
        }
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

    private func announce(_ message: String) {
        if voiceEnabled {
            speech.stopSpeaking(at: .immediate)
            let utterance = AVSpeechUtterance(string: message)
            utterance.voice = AVSpeechSynthesisVoice(language: "es-ES")
            speech.speak(utterance)
        }
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

private struct ReviewScreen: View {
    @State private var player: AVPlayer
    let isAnalyzing: Bool
    let progress: Double?
    let isCancelling: Bool
    let error: String?
    let onAnalyze: () -> Void
    let onAnalyzeMediaPipe: () -> Void
    let onAnalyzeKops: () -> Void
    let onCompareSilhouettes: () -> Void
    let onCancelAnalysis: () -> Void
    let onRetake: () -> Void
    let onClose: () -> Void

    init(url: URL, isAnalyzing: Bool, progress: Double?, isCancelling: Bool, error: String?, onAnalyze: @escaping () -> Void, onAnalyzeMediaPipe: @escaping () -> Void, onAnalyzeKops: @escaping () -> Void, onCompareSilhouettes: @escaping () -> Void, onCancelAnalysis: @escaping () -> Void, onRetake: @escaping () -> Void, onClose: @escaping () -> Void) {
        _player = State(initialValue: AVPlayer(url: url))
        self.isAnalyzing = isAnalyzing
        self.progress = progress
        self.isCancelling = isCancelling
        self.error = error
        self.onAnalyze = onAnalyze
        self.onAnalyzeMediaPipe = onAnalyzeMediaPipe
        self.onAnalyzeKops = onAnalyzeKops
        self.onCompareSilhouettes = onCompareSilhouettes
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
                    if let progress = progress {
                        ProgressView("Analizando vídeo · \(Int(progress * 100)) %", value: progress, total: 1)
                    } else {
                        ProgressView("Preparando análisis…")
                    }
                    if isCancelling {
                        Text("Cancelando al terminar el fotograma actual…")
                            .font(.footnote)
                    }
                    Button("Cancelar análisis", action: onCancelAnalysis)
                        .disabled(isCancelling)
                } else {
                    if let error = error {
                        Text(error).foregroundStyle(.red)
                    }
                    Button("Analizar vídeo", action: onAnalyze).buttonStyle(.borderedProminent)
                    Button("Analizar con MediaPipe (experimental)", action: onAnalyzeMediaPipe)
                        .buttonStyle(.bordered)
                    Button("Calibrar y analizar KOPS en vídeo", action: onAnalyzeKops)
                        .buttonStyle(.bordered)
                    Button("Comparar siluetas frontales", action: onCompareSilhouettes)
                        .buttonStyle(.bordered)
                    Text("MediaPipe puede medir también tobillo y pie si detecta la punta. Los motores pueden producir resultados distintos.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Repetir grabación", action: onRetake)
                    Button("Cerrar", action: onClose)
                }
            }
            .padding()
        }
        .onDisappear { player.pause() }
    }
}
