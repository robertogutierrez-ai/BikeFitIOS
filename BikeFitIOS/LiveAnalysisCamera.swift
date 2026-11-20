import AVFoundation
import Combine
import CoreVideo
import Foundation
import Vision

final class LiveAnalysisCamera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate {
    enum Mode {
        case lateral, frontal
    }

    private let mode: Mode
    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let queue = DispatchQueue(label: "com.bikefit.live-camera", qos: .userInitiated)
    private let request = VNDetectHumanBodyPoseRequest()
    private var input: AVCaptureDeviceInput?
    private var configured = false
    private var runID: Int?
    private var lastSampleTime: Double?
    private var frameVersion = 0
    private var accumulator: LiveSessionAccumulator?

    // These properties and the published state are accessed on the main thread.
    private var generation = 0
    private var measurementVersion = 0
    private var active = false
    private var orientation: AVCaptureVideoOrientation = .portrait
    private var pendingRecording = false
    private var discardRecording = false
    private var analysisFinished = false
    private var recordingFinished = true
    @Published private(set) var ready = false
    @Published private(set) var starting = false
    @Published private(set) var switching = false
    @Published private(set) var position: AVCaptureDevice.Position = .back
    @Published private(set) var angles: [JointAngle: Double] = [:]
    @Published private(set) var side: String?
    @Published private(set) var frontalSeparations: [VideoAnalyzer.Side: Double] = [:]
    @Published private(set) var canRecordVideo = false
    @Published private(set) var collecting = false
    @Published private(set) var finalizing = false
    @Published private(set) var startingRecording = false
    @Published private(set) var sessionResult: VideoAnalysisResult?
    @Published private(set) var recordedURL: URL?
    @Published var errorMessage: String?

    init(mode: Mode = .lateral) {
        self.mode = mode
        super.init()
    }

    func start() {
        guard !active else { return }
        active = true
        starting = true
        generation += 1
        let id = generation
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession(id: id)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    guard self.active, self.generation == id else { return }
                    if granted {
                        self.startSession(id: id)
                    } else {
                        self.fail("Necesitamos permiso de cámara. Puedes activarlo en Ajustes.")
                    }
                }
            }
        default:
            fail("Necesitamos permiso de cámara. Puedes activarlo en Ajustes.")
        }
    }

    private func startSession(id: Int) {
        let initialOrientation = orientation
        let version = measurementVersion
        queue.async {
            do {
                if !self.configured {
                    try self.configure()
                }
                self.runID = id
                self.frameVersion = version
                self.lastSampleTime = nil
                try self.setOutputOrientation(initialOrientation)
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                guard self.session.isRunning else { throw CameraError.startFailed }
                let actualPosition = self.input?.device.position ?? .back
                let canRecord = self.session.outputs.contains(self.movieOutput)
                DispatchQueue.main.async {
                    guard self.active, self.generation == id else { return }
                    self.starting = false
                    self.ready = true
                    self.position = actualPosition
                    self.canRecordVideo = canRecord
                }
            } catch {
                DispatchQueue.main.async {
                    guard self.active, self.generation == id else { return }
                    self.fail("No se pudo iniciar el análisis en directo: \(error.localizedDescription)")
                }
            }
        }
    }

    private func configure() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.cameraUnavailable
        }
        let cameraInput = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        guard session.canAddInput(cameraInput), session.canAddOutput(output) else {
            throw CameraError.configurationFailed
        }
        session.addInput(cameraInput)
        session.addOutput(output)
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        if session.canSetSessionPreset(.medium) {
            session.sessionPreset = .medium
        }
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        input = cameraInput
        configured = true
    }

    func setOrientation(_ newOrientation: AVCaptureVideoOrientation) {
        guard orientation != newOrientation else { return }
        if collecting || finalizing {
            orientation = newOrientation
            fail("La orientación ha cambiado durante la sesión. Inicia otra sesión con el teléfono fijo.")
            return
        }
        orientation = newOrientation
        angles = [:]
        side = nil
        frontalSeparations = [:]
        measurementVersion += 1
        let version = measurementVersion
        let id = generation
        guard active else { return }
        queue.async {
            self.frameVersion = version
            guard self.configured else { return }
            do {
                try self.setOutputOrientation(newOrientation)
            } catch {
                self.reportFrameError(error, id: id)
            }
            self.lastSampleTime = nil
        }
    }

    private func setOutputOrientation(_ orientation: AVCaptureVideoOrientation) throws {
        guard let connection = output.connection(with: .video), connection.isVideoOrientationSupported else {
            throw CameraError.orientationUnavailable
        }
        connection.videoOrientation = orientation
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
    }

    func switchCamera() {
        guard ready, !switching, !collecting, !finalizing else { return }
        switching = true
        angles = [:]
        side = nil
        frontalSeparations = [:]
        measurementVersion += 1
        let version = measurementVersion
        generation += 1
        let id = generation
        let next: AVCaptureDevice.Position = position == .back ? .front : .back
        let currentOrientation = orientation
        queue.async {
            self.runID = id
            self.frameVersion = version
            do {
                try self.replaceCamera(position: next)
                try self.setOutputOrientation(currentOrientation)
                self.lastSampleTime = nil
                DispatchQueue.main.async {
                    guard self.active, self.generation == id else { return }
                    self.position = next
                    self.switching = false
                }
            } catch {
                DispatchQueue.main.async {
                    guard self.active, self.generation == id else { return }
                    self.switching = false
                    self.fail("No se pudo cambiar de cámara: \(error.localizedDescription)")
                }
            }
        }
    }

    private func replaceCamera(position: AVCaptureDevice.Position) throws {
        guard let previous = input else { throw CameraError.configurationFailed }
        do {
            input = try CameraInputSwitcher.replace(in: session, current: previous, position: position)
        } catch CameraInputSwitcher.SwitchError.restoreFailed {
            session.beginConfiguration()
            session.removeOutput(output)
            if session.outputs.contains(movieOutput) { session.removeOutput(movieOutput) }
            session.commitConfiguration()
            input = nil
            configured = false
            throw CameraInputSwitcher.SwitchError.restoreFailed
        }
    }

    func shutdown() {
        generation += 1
        discardRecording = true
        if pendingRecording { movieOutput.stopRecording() }
        active = false
        ready = false
        starting = false
        switching = false
        angles = [:]
        side = nil
        frontalSeparations = [:]
        collecting = false
        finalizing = false
        startingRecording = false
        canRecordVideo = false
        queue.async {
            self.runID = nil
            self.accumulator = nil
            self.lastSampleTime = nil
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func beginSession(recordVideo: Bool) {
        guard mode == .lateral, ready, !switching, !collecting, !finalizing else { return }
        guard !pendingRecording else {
            errorMessage = "Espera a que termine la grabación anterior."
            return
        }
        guard recordedURL == nil else {
            errorMessage = "Elimina o revisa la grabación anterior antes de iniciar otra sesión."
            return
        }
        if recordVideo {
            guard canRecordVideo, let connection = movieOutput.connection(with: .video),
                  connection.isVideoOrientationSupported else {
                errorMessage = "No se puede grabar vídeo durante el análisis en este dispositivo."
                return
            }
            connection.videoOrientation = orientation
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }
        sessionResult = nil
        discardRecording = false
        analysisFinished = false
        recordingFinished = !recordVideo
        collecting = true
        queue.async { self.accumulator = LiveSessionAccumulator() }
        if recordVideo {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("bikefit-live-\(UUID().uuidString).mov")
            pendingRecording = true
            startingRecording = true
            movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func endSession() {
        guard collecting, !startingRecording else { return }
        collecting = false
        finalizing = true
        let id = generation
        queue.async {
            do {
                guard let accumulator = self.accumulator else { throw CameraError.noSession }
                let result = try accumulator.result()
                self.accumulator = nil
                DispatchQueue.main.async {
                    guard self.active, self.generation == id else { return }
                    self.sessionResult = result
                    self.analysisFinished = true
                    self.finishSessionIfReady()
                }
            } catch {
                self.accumulator = nil
                DispatchQueue.main.async {
                    guard self.active, self.generation == id else { return }
                    self.errorMessage = "No se pudo completar la sesión: \(error.localizedDescription)"
                    self.analysisFinished = true
                    self.finishSessionIfReady()
                }
            }
        }
        if pendingRecording { movieOutput.stopRecording() }
    }

    private func finishSessionIfReady() {
        if analysisFinished && recordingFinished { finalizing = false }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async {
            self.startingRecording = false
            if self.discardRecording { self.movieOutput.stopRecording() }
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            self.pendingRecording = false
            self.startingRecording = false
            self.recordingFinished = true
            if self.discardRecording || error != nil {
                do {
                    if FileManager.default.fileExists(atPath: outputFileURL.path) {
                        try FileManager.default.removeItem(at: outputFileURL)
                    }
                } catch {
                    self.errorMessage = "No se pudo eliminar la grabación temporal: \(error.localizedDescription)"
                }
                if let error = error, !self.discardRecording {
                    let message = "No se pudo guardar la grabación: \(error.localizedDescription)"
                    self.errorMessage = [message, self.errorMessage].compactMap { $0 }.joined(separator: " ")
                }
            } else {
                self.recordedURL = outputFileURL
            }
            self.finishSessionIfReady()
        }
    }

    func removeRecording() -> Bool {
        guard let url = recordedURL else { return true }
        do {
            try FileManager.default.removeItem(at: url)
            recordedURL = nil
            return true
        } catch {
            errorMessage = "No se pudo eliminar la grabación temporal: \(error.localizedDescription)"
            return false
        }
    }

    func takeRecording() -> URL? {
        let url = recordedURL
        recordedURL = nil
        return url
    }

    func fail(_ message: String) {
        guard active else { return }
        shutdown()
        errorMessage = message
    }

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let id = runID else { return }
        let version = frameVersion
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        guard time.isFinite else {
            reportFrameError(CameraError.invalidFrame, id: id)
            return
        }
        if let last = lastSampleTime, time >= last, time - last < 0.2 { return }
        lastSampleTime = time
        do {
            guard let image = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                throw CameraError.invalidFrame
            }
            let handler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .up, options: [:])
            try handler.perform([request])
            var measured: [VideoAnalyzer.Side: [JointAngle: Double]] = [:]
            var frontal: [VideoAnalyzer.Side: Double] = [:]
            if let observation = request.results?.first {
                switch mode {
                case .lateral:
                    measured = try VideoAnalyzer.measuredAngles(
                        observation: observation,
                        width: CGFloat(CVPixelBufferGetWidth(image)),
                        height: CGFloat(CVPixelBufferGetHeight(image))
                    )
                case .frontal:
                    frontal = try Self.frontalSeparations(observation: observation)
                }
            }
            let selected = Self.preferredSide(in: measured)
            if self.accumulator != nil {
                try self.accumulator?.add(time: time, measured: measured)
            }
            let values = selected.flatMap { self.accumulator?.latest(for: $0) ?? measured[$0] } ?? [:]
            let frontalValues = frontal
            DispatchQueue.main.async {
                guard self.active, self.generation == id, self.measurementVersion == version else { return }
                self.side = selected?.title
                self.angles = values
                self.frontalSeparations = frontalValues
            }
        } catch {
            reportFrameError(error, id: id)
        }
    }

    static func preferredSide(in measured: [VideoAnalyzer.Side: [JointAngle: Double]]) -> VideoAnalyzer.Side? {
        if measured[.left] != nil { return .left }
        if measured[.right] != nil { return .right }
        return nil
    }

    static func frontalSeparations(observation: VNHumanBodyPoseObservation) throws -> [VideoAnalyzer.Side: Double] {
        var result: [VideoAnalyzer.Side: Double] = [:]
        for side in VideoAnalyzer.Side.allCases {
            let knee = try observation.recognizedPoint(side.joints[4])
            let ankle = try observation.recognizedPoint(side.joints[5])
            guard knee.confidence >= 0.55, ankle.confidence >= 0.55,
                  let separation = FrontalKneeMeasurement.separation(knee: knee.location, ankle: ankle.location) else {
                continue
            }
            result[side] = separation
        }
        return result
    }

    private func reportFrameError(_ error: Error, id: Int) {
        runID = nil
        DispatchQueue.main.async {
            guard self.active, self.generation == id else { return }
            self.fail("No se pudo analizar la imagen de cámara: \(error.localizedDescription)")
        }
    }

    private enum CameraError: LocalizedError {
        case cameraUnavailable, configurationFailed, startFailed, invalidFrame, orientationUnavailable, noSession

        var errorDescription: String? {
            switch self {
            case .cameraUnavailable: return "La cámara solicitada no está disponible."
            case .configurationFailed: return "La cámara no admite la configuración necesaria."
            case .startFailed: return "La sesión de cámara no se ha iniciado."
            case .invalidFrame: return "El fotograma recibido no es válido."
            case .orientationUnavailable: return "No se puede orientar la imagen de cámara."
            case .noSession: return "La sesión no está disponible."
            }
        }
    }
}
