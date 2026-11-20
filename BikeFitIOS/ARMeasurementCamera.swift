import ARKit
import AVFoundation
import Combine
import Foundation
import simd

enum ARMeasurementMath {
    static func millimeters(from first: SIMD3<Float>, to second: SIMD3<Float>) -> Double? {
        guard [first.x, first.y, first.z, second.x, second.y, second.z].allSatisfy(\.isFinite) else { return nil }
        let value = Double(simd_distance(first, second)) * 1000
        return value.isFinite && value >= 1 ? value : nil
    }
}

final class ARMeasurementCamera: NSObject, ObservableObject, ARSessionDelegate {
    private weak var view: ARSCNView?
    private var active = false
    private var authorized = false
    private var running = false
    private var generation = 0
    private var firstAnchor: ARAnchor?
    @Published private(set) var tracking = false
    @Published private(set) var pointCount = 0
    @Published private(set) var distanceMillimeters: Double?
    @Published private(set) var status = "Preparando cámara AR…"
    @Published var errorMessage: String?

    func attach(_ view: ARSCNView) {
        self.view = view
        view.session.delegate = self
        view.session.delegateQueue = .main
        runIfReady()
    }

    func start() {
        guard !active else { return }
        guard ARWorldTrackingConfiguration.isSupported else {
            status = "AR no está disponible en este dispositivo."
            return
        }
        active = true
        generation += 1
        let id = generation
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorized = true
            runIfReady()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    guard self.active, self.generation == id else { return }
                    if granted {
                        self.authorized = true
                        self.runIfReady()
                    } else {
                        self.stop()
                        self.errorMessage = "Necesitamos permiso de cámara. Puedes activarlo en Ajustes."
                    }
                }
            }
        default:
            stop()
            errorMessage = "Necesitamos permiso de cámara. Puedes activarlo en Ajustes."
        }
    }

    private func runIfReady() {
        guard active, authorized, !running, let view = view else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        running = true
        status = "Mueve el iPhone lentamente para detectar superficies."
    }

    func markPoint() {
        guard running, tracking, pointCount < 2, let view = view else {
            errorMessage = "Espera a que el seguimiento AR esté disponible."
            return
        }
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        guard let query = view.raycastQuery(from: center, allowing: .estimatedPlane, alignment: .any),
              let hit = view.session.raycast(query).first else {
            errorMessage = "No se detectó una superficie en el centro. Cambia la posición o mejora la iluminación."
            return
        }
        if pointCount == 0 {
            let anchor = ARAnchor(transform: hit.worldTransform)
            view.session.add(anchor: anchor)
            firstAnchor = anchor
            pointCount = 1
            status = "Primer punto marcado. Apunta al segundo punto."
            return
        }
        guard let anchor = firstAnchor,
              let first = view.session.currentFrame?.anchors.first(where: { $0.identifier == anchor.identifier }) else {
            errorMessage = "El primer punto aún no está disponible. Espera un momento y vuelve a intentarlo."
            return
        }
        let a = first.transform.columns.3
        let b = hit.worldTransform.columns.3
        guard let distance = ARMeasurementMath.millimeters(
            from: SIMD3(a.x, a.y, a.z), to: SIMD3(b.x, b.y, b.z)
        ) else {
            errorMessage = "Los puntos están demasiado cerca o no son válidos."
            return
        }
        distanceMillimeters = distance
        pointCount = 2
        status = "Medición completada."
    }

    func reset() {
        if let anchor = firstAnchor, let view = view {
            view.session.remove(anchor: anchor)
        }
        firstAnchor = nil
        pointCount = 0
        distanceMillimeters = nil
        status = tracking ? "Apunta al primer punto." : "Esperando seguimiento AR."
    }

    func stop() {
        generation += 1
        active = false
        authorized = false
        running = false
        view?.session.pause()
        firstAnchor = nil
        pointCount = 0
        distanceMillimeters = nil
        tracking = false
        status = "Medición AR detenida."
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        guard active, view?.session === session else { return }
        if case .normal = camera.trackingState {
            tracking = true
            if pointCount == 0 { status = "Apunta al primer punto." }
        } else {
            tracking = false
            status = "Seguimiento limitado. Mueve el iPhone lentamente y mejora la iluminación."
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        guard active, view?.session === session else { return }
        stop()
        errorMessage = "La sesión AR se ha detenido: \(error.localizedDescription)"
    }

    func sessionWasInterrupted(_ session: ARSession) {
        guard active, view?.session === session else { return }
        stop()
        errorMessage = "La sesión AR se ha interrumpido. Vuelve a iniciarla para medir."
    }
}
