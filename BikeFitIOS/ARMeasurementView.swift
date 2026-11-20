import ARKit
import SwiftUI

struct ARMeasurementView: View {
    let onClose: () -> Void
    @StateObject private var camera = ARMeasurementCamera()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 10) {
            Text("Medición AR · experimental").font(.headline)
            Text("Apunta con la cruz a dos puntos sobre superficies detectables y marca cada uno.")
                .font(.subheadline)
                .padding(.horizontal)
            ZStack {
                ARMeasurementPreview(camera: camera)
                Image(systemName: "plus")
                    .font(.title)
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 3)
                    .allowsHitTesting(false)
            }
            .background(.black)
            Text(camera.status).font(.footnote)
            if let distance = camera.distanceMillimeters {
                Text(String(format: "Distancia aproximada: %.0f mm", distance))
                    .font(.headline)
            }
            Text("AR puede presentar errores importantes por superficies, iluminación y movimiento. No es una medición de precisión ni una recomendación de ajuste.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            HStack {
                Button("Marcar punto") { camera.markPoint() }
                    .disabled(!camera.tracking || camera.pointCount == 2)
                Button("Reiniciar") { camera.reset() }
                    .disabled(camera.pointCount == 0)
                if !camera.tracking {
                    Button("Reintentar") { camera.stop(); camera.start() }
                }
            }
            Button("Volver", action: onClose)
        }
        .onAppear {
            if scenePhase == .active { camera.start() }
        }
        .onDisappear { camera.stop() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { camera.start() } else { camera.stop() }
        }
        .alert("Medición AR", isPresented: Binding(
            get: { camera.errorMessage != nil },
            set: { if !$0 { camera.errorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(camera.errorMessage ?? "")
        }
    }
}

private struct ARMeasurementPreview: UIViewRepresentable {
    @ObservedObject var camera: ARMeasurementCamera

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        camera.attach(view)
        return view
    }

    func updateUIView(_ view: ARSCNView, context: Context) {}
}
