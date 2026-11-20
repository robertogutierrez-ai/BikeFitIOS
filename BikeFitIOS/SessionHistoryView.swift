import SwiftUI

struct SessionHistoryView: View {
    let onClose: () -> Void
    @State private var sessions: [SavedSession] = []
    @State private var error: String?
    @State private var pendingDeletion: SavedSession?
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Historial de sesiones").font(.title2.bold())
                Text("Solo se guardan resultados, no los vídeos. Son orientativos y no constituyen un diagnóstico.")
                    .foregroundStyle(.secondary)
                if loaded && sessions.isEmpty {
                    Text("No hay sesiones guardadas.")
                }
                ForEach(sessions) { session in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.savedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.headline)
                        Text("Lado \(session.result.side): \(session.result.validFrames) de \(session.result.sampledFrames) fotogramas válidos.")
                        ForEach(JointAngle.allCases, id: \.self) { angle in
                            if let range = session.result.ranges[angle] {
                                Text("\(angle.rawValue): \(String(format: "%.1f° – %.1f°", range.minimum, range.maximum))")
                            }
                        }
                        Button("Eliminar sesión", role: .destructive) {
                            pendingDeletion = session
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
                Button("Volver", action: onClose)
            }
            .padding()
        }
        .onAppear(perform: load)
        .confirmationDialog("¿Eliminar esta sesión?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), titleVisibility: .visible) {
            Button("Eliminar sesión", role: .destructive) {
                if let session = pendingDeletion { delete(session) }
                pendingDeletion = nil
            }
            Button("Cancelar", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("No se puede deshacer.")
        }
        .alert("Historial", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    private func load() {
        do {
            sessions = try SessionHistoryStore.standard().load()
            loaded = true
        } catch {
            loaded = false
            self.error = "No se pudo leer el historial: \(error.localizedDescription)"
        }
    }

    private func delete(_ session: SavedSession) {
        do {
            try SessionHistoryStore.standard().delete(session)
            sessions.removeAll { $0.id == session.id }
        } catch {
            self.error = "No se pudo eliminar la sesión: \(error.localizedDescription)"
        }
    }
}
