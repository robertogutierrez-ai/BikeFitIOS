import AVFoundation
import Combine
import SwiftUI

struct LiveAnalysisView: View {
    @StateObject private var camera = LiveAnalysisCamera()
    @Environment(\.scenePhase) private var scenePhase
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Análisis en directo · experimental")
                .font(.headline)
            Text("Coloca el iPhone fijo y de lado, con todo el cuerpo visible. No se graba vídeo.")
                .font(.subheadline)
                .padding(.horizontal)
            GeometryReader { geometry in
                CameraPreview(session: camera.session, onOrientationChange: camera.setOrientation)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .accessibilityLabel("Vista de cámara para análisis en directo")
            }
            .background(.black)
            if camera.starting {
                ProgressView("Iniciando cámara…")
            } else if let side = camera.side {
                Text("Lado \(side) · valores instantáneos")
                    .font(.subheadline)
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(JointAngle.allCases, id: \.self) { angle in
                            if let value = camera.angles[angle] {
                                HStack {
                                    Text(angle.rawValue)
                                    Spacer()
                                    Text(String(format: "%.1f°", value))
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 140)
            } else if camera.ready {
                Text("Buscando una postura completa; comprueba el encuadre y la iluminación.")
                    .font(.footnote)
            } else {
                Button("Reintentar cámara") { camera.start() }
            }
            Text("Valores orientativos, no validados clínicamente; pueden variar entre fotogramas y lados.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            HStack {
                Button("Cerrar", action: onClose)
                Spacer()
                Button(camera.position == .back ? "Usar cámara frontal" : "Usar cámara trasera") {
                    camera.switchCamera()
                }
                .disabled(!camera.ready || camera.switching)
            }
            .padding(.horizontal)
        }
        .onAppear {
            if scenePhase == .active { camera.start() }
        }
        .onDisappear { camera.shutdown() }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                camera.start()
            } else {
                camera.shutdown()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVCaptureSessionRuntimeError, object: camera.session).receive(on: DispatchQueue.main)) { notification in
            let error = notification.userInfo?[AVCaptureSessionErrorKey] as? Error
            camera.fail("La cámara se ha detenido: \(error?.localizedDescription ?? "error de la sesión").")
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVCaptureSessionWasInterrupted, object: camera.session).receive(on: DispatchQueue.main)) { _ in
            camera.fail("La cámara se ha interrumpido. Vuelve a intentarlo cuando esté disponible.")
        }
        .alert("Análisis en directo", isPresented: Binding(
            get: { camera.errorMessage != nil },
            set: { if !$0 { camera.errorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(camera.errorMessage ?? "")
        }
    }
}
