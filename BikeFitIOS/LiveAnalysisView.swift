import AVFoundation
import Combine
import SwiftUI

struct LiveAnalysisView: View {
    @StateObject private var camera: LiveAnalysisCamera
    @Environment(\.scenePhase) private var scenePhase
    private let mode: LiveAnalysisCamera.Mode
    let onClose: () -> Void

    init(mode: LiveAnalysisCamera.Mode = .lateral, onClose: @escaping () -> Void) {
        self.mode = mode
        self.onClose = onClose
        _camera = StateObject(wrappedValue: LiveAnalysisCamera(mode: mode))
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(mode == .frontal ? "Análisis frontal · experimental" : "Análisis en directo · experimental")
                .font(.headline)
            Text(mode == .frontal
                 ? "Coloca el iPhone fijo frente a la bicicleta, con ambas piernas visibles. No se graba vídeo."
                 : "Coloca el iPhone fijo y de lado, con todo el cuerpo visible. No se graba vídeo.")
                .font(.subheadline)
                .padding(.horizontal)
            GeometryReader { geometry in
                ZStack {
                    CameraPreview(session: camera.session, onOrientationChange: camera.setOrientation)
                        .accessibilityLabel("Vista de cámara para análisis en directo")
                    if mode == .frontal {
                        FramingGuide().allowsHitTesting(false)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
            .background(.black)
            if camera.starting {
                ProgressView("Iniciando cámara…")
            } else if mode == .frontal && !camera.frontalSeparations.isEmpty {
                VStack(spacing: 4) {
                    Text("Separación horizontal rodilla–tobillo").font(.subheadline)
                    ForEach(VideoAnalyzer.Side.allCases, id: \.self) { side in
                        if let value = camera.frontalSeparations[side] {
                            Text(String(format: "Lado %@: %.1f %% del ancho de imagen", side.title, value))
                        }
                    }
                }
            } else if mode == .lateral, let side = camera.side {
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
                Text(mode == .frontal
                     ? "Buscando rodillas y tobillos; comprueba el encuadre y la iluminación."
                     : "Buscando una postura completa; comprueba el encuadre y la iluminación.")
                    .font(.footnote)
            } else {
                Button("Reintentar cámara") { camera.start() }
            }
            Text(mode == .frontal
                 ? "Distancias 2D instantáneas sin dirección ni escala real. Dependen del encuadre y de la fase de pedaleo; no indican alineación correcta ni son un diagnóstico."
                 : "Valores orientativos, no validados clínicamente; pueden variar entre fotogramas y lados.")
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
