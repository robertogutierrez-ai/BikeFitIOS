import AVFoundation
import SwiftUI
import UIKit

struct CleatAssistantView: View {
    let onClose: () -> Void
    @State private var side = 0
    @State private var image: UIImage?
    @State private var points: [CGPoint] = []
    @State private var left: CleatMeasurement?
    @State private var right: CleatMeasurement?
    @State private var showingCamera = false
    @State private var error: String?
    @State private var history: [CleatSetup] = []
    @State private var note = ""
    @State private var symptom = "Ninguna"
    @State private var comfort = 3
    @State private var savedCurrentSetupID: UUID?

    private let historyStore = CleatHistoryStore()

    private let instructions = [
        "Marca la punta de la zapatilla.",
        "Marca el centro del talón de la zapatilla.",
        "Marca el extremo de la cala que apunta hacia la punta.",
        "Marca el extremo de la cala que apunta hacia el talón."
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Asistente de calas").font(.title2.bold())
                if let left = left, let right = right {
                    results(left: left, right: right)
                } else if let image = image {
                    Text("Zapatilla \(side == 0 ? "izquierda" : "derecha")").font(.headline)
                    Text(points.count < 4 ? instructions[points.count] : "Comprueba los cuatro puntos antes de continuar.")
                    CleatMarkingView(image: image, points: $points)
                        .frame(height: 340)
                    Text("Azul: eje de la zapatilla · Naranja: eje de la cala")
                        .font(.caption)
                    HStack {
                        Button("Deshacer punto") { points.removeLast() }
                            .disabled(points.isEmpty)
                        Spacer()
                        Button("Repetir foto") {
                            self.image = nil
                            points = []
                        }
                    }
                    Button(side == 0 ? "Continuar con la derecha" : "Ver resultados") {
                        finishMeasurement()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(points.count != 4)
                } else {
                    Text("Zapatilla \(side == 0 ? "izquierda" : "derecha")").font(.headline)
                    Text("Coloca la suela hacia la cámara, con la cala visible. Fotografía desde arriba, perpendicular a la suela, con buena luz y sin perspectiva.")
                    Text("Para ambas fotos, conserva la misma orientación de la punta, la distancia y el encuadre. Mantén la zapatilla y la cala inmóviles durante la foto.")
                    Button("Fotografiar suela") { openCamera() }
                        .buttonStyle(.borderedProminent)
                }
                if image == nil, !history.isEmpty {
                    Text("Historial local · últimas \(history.count) mediciones").font(.headline)
                    ForEach(history) { setup in
                        historyRow(setup)
                    }
                }
                Button("Salir", action: onClose)
            }
            .padding()
        }
        .onAppear(perform: loadHistory)
        .sheet(isPresented: $showingCamera) {
            CleatCamera { captured in
                image = captured
                points = []
                showingCamera = false
            } onCancel: {
                showingCamera = false
            } onError: {
                showingCamera = false
                error = "No se pudo obtener la fotografía. Vuelve a intentarlo."
            }
            .ignoresSafeArea()
        }
        .alert("Asistente de calas", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera),
              UIImagePickerController.isCameraDeviceAvailable(.rear) else {
            error = "La cámara trasera no está disponible en este dispositivo."
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showingCamera = true
                    } else {
                        error = "Necesitamos permiso de cámara. Puedes activarlo en Ajustes."
                    }
                }
            }
        default:
            error = "Necesitamos permiso de cámara. Puedes activarlo en Ajustes."
        }
    }

    private func finishMeasurement() {
        guard points.count == 4,
              let measurement = CleatMeasurement.calculate(
                shoeFront: points[0], shoeHeel: points[1],
                cleatFront: points[2], cleatHeel: points[3]
              ) else {
            error = "Los ejes son demasiado cortos o inválidos. Deshaz los puntos y vuelve a marcarlos."
            return
        }
        if side == 0 {
            left = measurement
            side = 1
            image = nil
            points = []
        } else {
            right = measurement
            image = nil
            points = []
        }
    }

    private func results(left: CleatMeasurement, right: CleatMeasurement) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Medición manual").font(.headline)
            resultRow("Izquierda", measurement: left)
            resultRow("Derecha", measurement: right)
            Text("Los desplazamientos son fracciones de la longitud del eje marcado de la zapatilla, no milímetros. El signo depende de la orientación de la foto y del orden de los puntos; no indica por sí solo interior o exterior.")
            Text("Los resultados son orientativos, dependen de la perspectiva y del marcado y no se han validado con iPhone ni comparado con Android. La simetría no implica una posición correcta; no constituyen un diagnóstico ni una recomendación de ajuste.")
            if let previous = previousSetup {
                comparison(left: left, right: right, previous: previous)
            }
            Text("Guarda la medición solo si quieres conservarla en el historial local. Las fotos no se guardan ni se envían a servidores.")
            Group {
                Stepper("Comodidad: \(comfort)/5", value: $comfort, in: 1...5)
                Picker("Molestia", selection: $symptom) {
                    ForEach(["Ninguna", "Dolor", "Entumecimiento", "Presión", "Otra"], id: \.self) { value in
                        Text(value).tag(value)
                    }
                }
                TextField("Nota opcional", text: $note, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
            }
            .disabled(savedCurrentSetupID != nil)
            Button(savedCurrentSetupID != nil ? "Medición guardada" : "Guardar en el historial") {
                saveCurrentMeasurement(left: left, right: right)
            }
            .buttonStyle(.borderedProminent)
            .disabled(savedCurrentSetupID != nil)
            Button("Empezar de nuevo") {
                leftReset()
            }
            .buttonStyle(.bordered)
        }
    }

    private func resultRow(_ title: String, measurement: CleatMeasurement) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            Text(String(format: "Rotación: %.1f°", measurement.rotationDegrees))
            Text(String(format: "Desplazamiento lateral relativo: %.3f", measurement.lateralRelativeToShoe))
            Text(String(format: "Desplazamiento longitudinal relativo: %.3f", measurement.longitudinalRelativeToShoe))
        }
    }

    private var previousSetup: CleatSetup? {
        guard let savedCurrentSetupID,
              history.first?.id == savedCurrentSetupID else {
            return history.first
        }
        return history.dropFirst().first
    }

    private func comparison(left: CleatMeasurement, right: CleatMeasurement, previous: CleatSetup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Diferencia frente a la medición anterior").font(.headline)
            Text(String(format: "Izquierda: rotación %+.1f° · lateral %+.3f",
                        CleatMeasurement.normalizedRotation(left.rotationDegrees - previous.left.rotationDegrees),
                        left.lateralRelativeToShoe - previous.left.lateralRelativeToShoe))
            Text(String(format: "Derecha: rotación %+.1f° · lateral %+.3f",
                        CleatMeasurement.normalizedRotation(right.rotationDegrees - previous.right.rotationDegrees),
                        right.lateralRelativeToShoe - previous.right.lateralRelativeToShoe))
            Text("Compara solo fotos tomadas con la misma orientación y encuadre. La diferencia es orientativa y no recomienda ajustes.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func historyRow(_ setup: CleatSetup) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(setup.savedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                Spacer()
                Button("Eliminar", role: .destructive) {
                    deleteSetup(setup)
                }
                .font(.caption)
            }
            Text("Comodidad: \(setup.comfort)/5 · \(setup.symptom)")
            if !setup.note.isEmpty {
                Text(setup.note)
            }
            Text(String(format: "I: %.1f° / %.3f · D: %.1f° / %.3f",
                        setup.left.rotationDegrees, setup.left.lateralRelativeToShoe,
                        setup.right.rotationDegrees, setup.right.lateralRelativeToShoe))
                .font(.caption.monospacedDigit())
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    private func loadHistory() {
        do {
            history = try historyStore.load()
        } catch {
            self.error = "No se pudo leer el historial local: \(error.localizedDescription)"
        }
    }

    private func saveCurrentMeasurement(left: CleatMeasurement, right: CleatMeasurement) {
        do {
            history = try historyStore.save(
                left: left,
                right: right,
                note: note,
                comfort: comfort,
                symptom: symptom
            )
            savedCurrentSetupID = history.first?.id
        } catch {
            self.error = "No se pudo guardar la medición: \(error.localizedDescription)"
        }
    }

    private func deleteSetup(_ setup: CleatSetup) {
        do {
            history = try historyStore.delete(id: setup.id)
            if setup.id == savedCurrentSetupID {
                savedCurrentSetupID = nil
            }
        } catch {
            self.error = "No se pudo eliminar la medición: \(error.localizedDescription)"
        }
    }

    private func leftReset() {
        side = 0
        left = nil
        right = nil
        image = nil
        points = []
        note = ""
        symptom = "Ninguna"
        comfort = 3
        savedCurrentSetupID = nil
    }
}

private struct CleatMarkingView: View {
    let image: UIImage
    @Binding var points: [CGPoint]

    var body: some View {
        GeometryReader { geometry in
            let rect = imageRect(imageSize: image.size, available: geometry.size)
            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                Path { path in
                    for start in [0, 2] where points.count > start + 1 {
                        path.move(to: screenPoint(points[start], rect: rect))
                        path.addLine(to: screenPoint(points[start + 1], rect: rect))
                    }
                }
                .stroke(.white, lineWidth: 3)
                ForEach(points.indices, id: \.self) { index in
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .frame(width: 26, height: 26)
                        .background(index < 2 ? Color.cyan : Color.orange, in: Circle())
                        .position(screenPoint(points[index], rect: rect))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                guard points.count < 4, rect.contains(value.location), rect.width > 0 else { return }
                points.append(CGPoint(
                    x: (value.location.x - rect.minX) / rect.width,
                    y: (value.location.y - rect.minY) / rect.width
                ))
            })
        }
        .background(.black)
        .accessibilityLabel("Fotografía de la suela. Toca los puntos indicados para marcar los ejes.")
    }

    private func imageRect(imageSize: CGSize, available: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(available.width / imageSize.width, available.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (available.width - size.width) / 2, y: (available.height - size.height) / 2, width: size.width, height: size.height)
    }

    private func screenPoint(_ point: CGPoint, rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.width)
    }
}

private struct CleatCamera: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void
    let onError: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture, onCancel: onCancel, onError: onError) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .rear
        picker.mediaTypes = ["public.image"]
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void
        let onError: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void, onError: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
            self.onError = onError
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else {
                onError()
                return
            }
            onCapture(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
