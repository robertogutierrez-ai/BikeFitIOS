import AVFoundation
import SwiftUI
import UIKit

final class CameraCapture: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    private let output = AVCaptureMovieFileOutput()
    private let queue = DispatchQueue(label: "com.bikefit.camera")
    private var configured = false
    private var shouldRun = false
    private var discardRecording = false
    var onFinished: ((URL) -> Void)?

    @Published private(set) var ready = false
    @Published private(set) var recording = false
    @Published private(set) var finishing = false
    @Published var errorMessage: String?

    func start() {
        queue.async { self.shouldRun = true }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.configureAndStart()
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Necesitamos permiso de cámara. Puedes activarlo en Ajustes."
                    }
                }
            }
        default:
            errorMessage = "Necesitamos permiso de cámara. Puedes activarlo en Ajustes."
        }
    }

    private func configureAndStart() {
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
                    if self.session.canSetSessionPreset(.high) {
                        self.session.sessionPreset = .high
                    }
                    self.configured = true
                }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                DispatchQueue.main.async {
                    self.ready = self.session.isRunning
                    if !self.ready {
                        self.errorMessage = "No se pudo iniciar la cámara."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "No se pudo iniciar la cámara: \(error.localizedDescription)"
                }
            }
        }
    }

    func record(orientation: AVCaptureVideoOrientation) {
        guard ready, !recording, !finishing else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bikefit-\(UUID().uuidString).mov")
        discardRecording = false
        if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = orientation
        }
        recording = true
        output.startRecording(to: url, recordingDelegate: self)
    }

    func stop() {
        guard recording, !finishing else { return }
        finishing = true
        output.stopRecording()
    }

    func shutdown() {
        if recording {
            discardRecording = true
            stop()
        }
        ready = false
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

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.updateOrientation()
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateOrientation()
    }

    func updateOrientation() {
        if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = currentVideoOrientation(window?.windowScene?.interfaceOrientation)
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
