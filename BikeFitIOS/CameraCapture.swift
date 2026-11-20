import AVFoundation
import SwiftUI
import UIKit

final class CameraCapture: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    private let output = AVCaptureMovieFileOutput()
    private let queue = DispatchQueue(label: "com.bikefit.camera")
    private var configured = false
    private var input: AVCaptureDeviceInput?
    private var shouldRun = false
    private var discardRecording = false
    private var generation = 0
    var onFinished: ((URL) -> Void)?

    @Published private(set) var ready = false
    @Published private(set) var starting = false
    @Published private(set) var recording = false
    @Published private(set) var finishing = false
    @Published private(set) var switching = false
    @Published private(set) var position: AVCaptureDevice.Position = .back
    @Published var errorMessage: String?

    var canSwitchCamera: Bool {
        Self.canSwitchCamera(ready: ready, recording: recording, finishing: finishing, switching: switching)
    }

    static func canSwitchCamera(ready: Bool, recording: Bool, finishing: Bool, switching: Bool) -> Bool {
        ready && !recording && !finishing && !switching
    }

    func start() {
        guard !ready, !starting else { return }
        starting = true
        let id = generation
        queue.async { self.shouldRun = true }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart(id: id)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    guard self.generation == id else { return }
                    if granted {
                        self.configureAndStart(id: id)
                    } else {
                        self.starting = false
                        self.errorMessage = "Necesitamos permiso de cámara. Puedes activarlo en Ajustes."
                    }
                }
            }
        default:
            starting = false
            errorMessage = "Necesitamos permiso de cámara. Puedes activarlo en Ajustes."
        }
    }

    private func configureAndStart(id: Int) {
        queue.async {
            guard self.shouldRun else { return }
            do {
                if !self.configured {
                    guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                        throw CaptureError.cameraUnavailable
                    }
                    let input = try AVCaptureDeviceInput(device: camera)
                    self.session.beginConfiguration()
                    defer { self.session.commitConfiguration() }
                    guard self.session.canAddInput(input), self.session.canAddOutput(self.output) else {
                        throw CaptureError.configurationFailed
                    }
                    self.session.addInput(input)
                    self.session.addOutput(self.output)
                    self.input = input
                    if self.session.canSetSessionPreset(.high) {
                        self.session.sessionPreset = .high
                    }
                    self.configured = true
                }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                let running = self.session.isRunning
                let position = self.input?.device.position
                DispatchQueue.main.async {
                    guard self.generation == id else { return }
                    self.starting = false
                    self.ready = running
                    if let position = position { self.position = position }
                    if !self.ready {
                        self.errorMessage = "No se pudo iniciar la cámara."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    guard self.generation == id else { return }
                    self.starting = false
                    self.errorMessage = "No se pudo iniciar la cámara: \(error.localizedDescription)"
                }
            }
        }
    }

    func record(orientation: AVCaptureVideoOrientation) {
        guard ready, !recording, !finishing, !switching else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bikefit-\(UUID().uuidString).mov")
        discardRecording = false
        guard let connection = output.connection(with: .video), connection.isVideoOrientationSupported else {
            errorMessage = "No se puede orientar el vídeo de la cámara."
            return
        }
        connection.videoOrientation = orientation
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
        recording = true
        output.startRecording(to: url, recordingDelegate: self)
    }

    func switchCamera() {
        guard canSwitchCamera else { return }
        switching = true
        let id = generation
        let next: AVCaptureDevice.Position = position == .back ? .front : .back
        queue.async {
            do {
                guard let input = self.input else { throw CaptureError.configurationFailed }
                self.input = try CameraInputSwitcher.replace(in: self.session, current: input, position: next)
                DispatchQueue.main.async {
                    guard self.generation == id else { return }
                    self.position = next
                    self.switching = false
                }
            } catch {
                let restoreFailed = (error as? CameraInputSwitcher.SwitchError) == .restoreFailed
                if restoreFailed {
                    if self.session.isRunning { self.session.stopRunning() }
                    self.session.beginConfiguration()
                    self.session.removeOutput(self.output)
                    self.session.commitConfiguration()
                    self.input = nil
                    self.configured = false
                }
                DispatchQueue.main.async {
                    guard self.generation == id else { return }
                    self.switching = false
                    if restoreFailed { self.ready = false }
                    self.errorMessage = "No se pudo cambiar de cámara: \(error.localizedDescription)"
                }
            }
        }
    }

    func stop() {
        guard recording, !finishing else { return }
        finishing = true
        output.stopRecording()
    }

    func shutdown() {
        generation += 1
        if recording {
            discardRecording = true
            stop()
        }
        ready = false
        starting = false
        switching = false
        queue.async {
            self.shouldRun = false
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.recording = false
            self.finishing = false
            if self.discardRecording {
                self.removeRecording(outputFileURL)
                return
            }
            if let error = error {
                self.removeRecording(outputFileURL)
                self.errorMessage = "No se pudo guardar el vídeo: \(error.localizedDescription)"
                return
            }
            self.onFinished?(outputFileURL)
        }
    }

    private func removeRecording(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            errorMessage = "No se pudo eliminar la grabación temporal: \(error.localizedDescription)"
        }
    }

    private enum CaptureError: LocalizedError {
        case cameraUnavailable
        case configurationFailed

        var errorDescription: String? {
            switch self {
            case .cameraUnavailable: return "La cámara trasera no está disponible."
            case .configurationFailed: return "La cámara no admite la configuración necesaria."
            }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var onOrientationChange: ((AVCaptureVideoOrientation) -> Void)? = nil

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onOrientationChange = onOrientationChange
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.onOrientationChange = onOrientationChange
        uiView.updateOrientation()
    }
}

final class PreviewView: UIView {
    var onOrientationChange: ((AVCaptureVideoOrientation) -> Void)?
    private var lastNotifiedOrientation: AVCaptureVideoOrientation?
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateOrientation()
    }

    func updateOrientation() {
        let orientation = currentVideoOrientation(window?.windowScene?.interfaceOrientation)
        if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = orientation
        }
        if lastNotifiedOrientation != orientation, let onOrientationChange = onOrientationChange {
            lastNotifiedOrientation = orientation
            DispatchQueue.main.async { onOrientationChange(orientation) }
        }
    }
}

func currentVideoOrientation(_ orientation: UIInterfaceOrientation?) -> AVCaptureVideoOrientation {
    switch orientation {
    case .landscapeLeft: return .landscapeLeft
    case .landscapeRight: return .landscapeRight
    case .portraitUpsideDown: return .portraitUpsideDown
    default: return .portrait
    }
}
