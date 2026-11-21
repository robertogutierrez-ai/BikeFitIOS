import AVFoundation
import SwiftUI
import UIKit

struct PhaseImagesView: View {
    let session: SavedSession
    var videoURL: URL? = nil
    var onBusyChange: (Bool) -> Void = { _ in }
    @State private var images: [String: Data] = [:]
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let phases = session.result.phases, !phases.isEmpty {
                Text("Fotogramas de fases estimadas").font(.headline)
                ForEach(phases, id: \.kind.rawValue) { phase in
                    Text(String(format: "%@ · instante solicitado %.2f s", phase.kind.title, phase.time))
                    if let data = images[phase.kind.rawValue], let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 160)
                    }
                }
                Text("Son extremos observados del tobillo. La dirección se indica al calibrar KOPS o se estima mediante cadera y rodilla. No son fases anatómicas verificadas y el instante extraído puede variar.")
                    .font(.footnote).foregroundStyle(.secondary)
                if let url = videoURL {
                    Button(images.isEmpty ? "Guardar imágenes de fases" : "Actualizar imágenes de fases") {
                        save(from: url, phases: phases)
                    }
                    .disabled(busy)
                }
                if !images.isEmpty {
                    Button("Eliminar imágenes de fases", role: .destructive) { delete() }
                        .disabled(busy)
                }
                if busy { ProgressView("Guardando imágenes…") }
            }
        }
        .onAppear(perform: load)
        .alert("Imágenes de fases", isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private func load() {
        do {
            images = try SessionHistoryStore.standard().phaseImages(for: session)
            for data in images.values where UIImage(data: data) == nil {
                throw SnapshotError.invalidImage
            }
        } catch {
            self.error = "No se pudieron leer las imágenes de fases: \(error.localizedDescription)"
        }
    }

    private func save(from url: URL, phases: [PedalingPhase]) {
        busy = true
        onBusyChange(true)
        Task {
            do {
                let snapshots = try await Task.detached(priority: .userInitiated) {
                    try PhaseImageExtractor.extract(from: url, phases: phases)
                }.value
                try SessionHistoryStore.standard().savePhaseImages(snapshots, for: session)
                images = snapshots
            } catch {
                self.error = "No se pudieron guardar las imágenes: \(error.localizedDescription)"
            }
            busy = false
            onBusyChange(false)
        }
    }

    private func delete() {
        do {
            try SessionHistoryStore.standard().deletePhaseImages(session)
            images = [:]
        } catch {
            self.error = "No se pudieron eliminar las imágenes: \(error.localizedDescription)"
        }
    }

    private enum SnapshotError: LocalizedError {
        case invalidImage
        var errorDescription: String? { "La imagen guardada no es válida." }
    }
}
