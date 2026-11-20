import AVFoundation
import Combine
import CoreVideo
import Foundation
import Vision

final class LiveAnalysisCamera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.bikefit.live-camera", qos: .userInitiated)
    private let request = VNDetectHumanBodyPoseRequest()
    private var input: AVCaptureDeviceInput?
    private var configured = false
    private var runID: Int?
    private var lastSampleTime: Double?
    private var frameVersion = 0

    // These properties and the published state are accessed on the main thread.
    private var generation = 0
    private var measurementVersion = 0
    private var active = false
    private var orientation: AVCaptureVideoOrientation = .portrait
    @Published private(set) var ready = false
    @Published private(set) var starting = false
    @Published private(set) var switching = false
    @Published private(set) var position: AVCaptureDevice.Position = .back
    @Published private(set) var angles: [JointAngle: Double] = [:]
    @Published private(set) var side: String?
    @Published var errorMessage: String?

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
                DispatchQueue.main.async {
                    guard self.active, self.generation == id else { return }
                    self.starting = false
                    self.ready = true
                    self.position = actualPosition
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
        orientation = newOrientation
        angles = [:]
        side = nil
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
        guard ready, !switching else { return }
        switching = true
        angles = [:]
        side = nil
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
            session.commitConfiguration()
            input = nil
            configured = false
            throw CameraInputSwitcher.SwitchError.restoreFailed
        }
    }

    func shutdown() {
        generation += 1
        active = false
        ready = false
        starting = false
        switching = false
        angles = [:]
        side = nil
        queue.async {
            self.runID = nil
            self.lastSampleTime = nil
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
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
            if let observation = request.results?.first {
                measured = try VideoAnalyzer.measuredAngles(
                    observation: observation,
                    width: CGFloat(CVPixelBufferGetWidth(image)),
                    height: CGFloat(CVPixelBufferGetHeight(image))
                )
            }
            let selected = Self.preferredSide(in: measured)
            let values = selected.flatMap { measured[$0] } ?? [:]
            DispatchQueue.main.async {
                guard self.active, self.generation == id, self.measurementVersion == version else { return }
                self.side = selected?.title
                self.angles = values
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

    private func reportFrameError(_ error: Error, id: Int) {
        runID = nil
        DispatchQueue.main.async {
            guard self.active, self.generation == id else { return }
            self.fail("No se pudo analizar la imagen de cámara: \(error.localizedDescription)")
        }
    }

    private enum CameraError: LocalizedError {
        case cameraUnavailable, configurationFailed, startFailed, invalidFrame, orientationUnavailable

        var errorDescription: String? {
            switch self {
            case .cameraUnavailable: return "La cámara solicitada no está disponible."
            case .configurationFailed: return "La cámara no admite la configuración necesaria."
            case .startFailed: return "La sesión de cámara no se ha iniciado."
            case .invalidFrame: return "El fotograma recibido no es válido."
            case .orientationUnavailable: return "No se puede orientar la imagen de cámara."
            }
        }
    }
}
