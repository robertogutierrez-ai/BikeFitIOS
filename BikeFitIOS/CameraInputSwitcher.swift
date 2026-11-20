import AVFoundation
import Foundation

enum CameraInputSwitcher {
    static func replace(
        in session: AVCaptureSession,
        current: AVCaptureDeviceInput,
        position: AVCaptureDevice.Position
    ) throws -> AVCaptureDeviceInput {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw SwitchError.cameraUnavailable
        }
        let replacement = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.removeInput(current)
        guard session.canAddInput(replacement) else {
            guard session.canAddInput(current) else { throw SwitchError.restoreFailed }
            session.addInput(current)
            throw SwitchError.configurationFailed
        }
        session.addInput(replacement)
        return replacement
    }

    enum SwitchError: LocalizedError {
        case cameraUnavailable, configurationFailed, restoreFailed

        var errorDescription: String? {
            switch self {
            case .cameraUnavailable: return "La cámara solicitada no está disponible."
            case .configurationFailed: return "La cámara no admite la configuración necesaria."
            case .restoreFailed: return "No se pudo recuperar la cámara anterior."
            }
        }
    }
}
