import SwiftUI
import UIKit

struct SessionHistoryView: View {
    let onClose: () -> Void
    @State private var sessions: [SavedSession] = []
    @State private var error: String?
    @State private var pendingDeletion: SavedSession?
    @State private var loaded = false
    @State private var selectedIDs: [UUID] = []
    @State private var comparisonMode: SessionComparison.Mode = .general
    @State private var comparisonImages: [UUID: UIImage] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Historial de sesiones").font(.title2.bold())
                Text("Se guardan resultados y, solo si las eliges, imágenes. Los vídeos no se guardan. Los resultados son orientativos y no constituyen un diagnóstico.")
                    .foregroundStyle(.secondary)
                if loaded && sessions.isEmpty {
                    Text("No hay sesiones guardadas.")
                }
                if sessions.count >= 2 {
                    Picker("Tipo de comparación", selection: $comparisonMode) {
                        ForEach(SessionComparison.Mode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    comparisonInstructions
                    if selectedIDs.count == 2,
                       let baseline = sessions.first(where: { $0.id == selectedIDs[0] }),
                       let comparison = sessions.first(where: { $0.id == selectedIDs[1] }) {
                        comparisonView(baseline: baseline, comparison: comparison)
                    }
                }
                ForEach(sessions) { session in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.savedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.headline)
                        Text("Lado \(session.result.side): \(session.result.validFrames) de \(session.result.sampledFrames) fotogramas válidos.")
                        Text("Motor: \((session.result.engine ?? .vision).rawValue)")
                        if let cycles = session.result.estimatedCycles {
                            Text("Ciclos aproximados: \(cycles) · estimación experimental")
                        }
                        if let kops = session.result.kops {
                            if let offset = kops.offsetMillimeters, let time = kops.time {
                                Text(String(format: "KOPS experimental: %+.1f mm · %.2f s · %d muestras", offset, time, kops.validSamples))
                                Text("Positivo hacia el avance indicado (\(kops.facingRight ? "derecha" : "izquierda") de la imagen); pedal aproximado entre tobillo y punta. No es un diagnóstico ni una recomendación de ajuste.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("KOPS no disponible: no hubo muestras válidas del pie.")
                                    .font(.footnote)
                            }
                        }
                        ForEach(JointAngle.allCases, id: \.self) { angle in
                            if let range = session.result.ranges[angle] {
                                Text("\(angle.rawValue): \(String(format: "%.1f° – %.1f°", range.minimum, range.maximum))")
                            }
                        }
                        if let samples = session.result.timeline, !samples.isEmpty {
                            DisclosureGroup("Ver gráfica") {
                                AngleTimelineView(samples: samples)
                            }
                            AngleStatisticsView(samples: samples)
                        }
                        if sessions.count >= 2 {
                            Button(selectionTitle(for: session)) {
                                toggleSelection(session)
                            }
                            .disabled(selectedIDs.count == 2 && !selectedIDs.contains(session.id))
                        }
                        SessionPhotoView(session: session, onChange: loadComparisonImages)
                        SessionInsightsView(result: session.result, date: session.savedAt)
                        Button("Eliminar sesión", role: .destructive) {
                            pendingDeletion = session
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
                Button("Volver", action: onClose)
            }
            .padding()
        }
        .onAppear(perform: load)
        .onChange(of: selectedIDs) { _ in loadComparisonImages() }
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

    private var comparisonInstructions: some View {
        Group {
            switch comparisonMode {
            case .general:
                Text("Selecciona dos sesiones para comparar: primero la base y después la segunda.")
            case .beforeAfter:
                Text("Selecciona primero una sesión antes y después otra posterior, del mismo lado y con el mismo motor. La fecha es la de guardado, no necesariamente la de grabación.")
            case .bilateral:
                Text("Selecciona dos sesiones, una por cada lado, con el mismo motor. Graba cada lado por separado en condiciones similares.")
            }
        }
        .font(.footnote)
    }

    private func comparisonView(baseline: SavedSession, comparison: SavedSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(comparisonMode.rawValue): segunda menos base").font(.headline)
            Text("Base: \(baseline.savedAt.formatted(date: .abbreviated, time: .shortened)) · lado \(baseline.result.side)")
            Text("Segunda: \(comparison.savedAt.formatted(date: .abbreviated, time: .shortened)) · lado \(comparison.result.side)")
            if let reason = SessionComparison.unavailableReason(
                mode: comparisonMode, baseline: baseline.result, comparison: comparison.result
            ) {
                Text(reason).foregroundStyle(.secondary)
            } else {
                if let firstImage = comparisonImages[baseline.id], let secondImage = comparisonImages[comparison.id] {
                    Text("Comparación visual").font(.headline)
                    HStack(alignment: .top) {
                        VStack { Text("Base"); Image(uiImage: firstImage).resizable().scaledToFit() }
                        VStack { Text("Segunda"); Image(uiImage: secondImage).resizable().scaledToFit() }
                    }
                    Text("Las imágenes se muestran sin alineación automática; el encuadre y la fase de pedaleo pueden ser diferentes.")
                        .font(.footnote)
                }
                if comparisonMode == .general && baseline.result.side != comparison.result.side {
                    Text("Se han analizado lados diferentes; las diferencias pueden reflejar esa variación.")
                        .foregroundStyle(.secondary)
                }
                if (baseline.result.engine ?? .vision) != (comparison.result.engine ?? .vision) {
                    Text("Se han utilizado motores de pose diferentes; sus mediciones pueden no ser comparables.")
                        .foregroundStyle(.secondary)
                }
                Text("Seguimiento: \(baseline.result.validFrames)/\(baseline.result.sampledFrames) y \(comparison.result.validFrames)/\(comparison.result.sampledFrames) fotogramas.")
                    .font(.footnote)
                if !JointAngle.allCases.contains(where: {
                    SessionComparison.difference(for: $0, baseline: baseline.result, comparison: comparison.result) != nil
                }) {
                    Text("No hay métricas comunes para comparar.").font(.footnote)
                }
                ForEach(JointAngle.allCases, id: \.self) { angle in
                    if let difference = SessionComparison.difference(for: angle, baseline: baseline.result, comparison: comparison.result) {
                        Text("\(angle.rawValue): \(String(format: "mín. %+.1f° · máx. %+.1f°", difference.minimum, difference.maximum))")
                        if let mean = SessionComparison.meanDifference(for: angle, baseline: baseline.result, comparison: comparison.result) {
                            Text("Diferencia entre medias: \(String(format: "%+.1f°", mean.value)) (\(mean.baselineCount) y \(mean.comparisonCount) muestras)")
                                .font(.footnote)
                        }
                    }
                }
                Text("Son diferencias descriptivas, no detectan fatiga ni asimetrías clínicas. Dependen del encuadre, del pedaleo y de las muestras válidas; no indican una mejora ni un ajuste recomendado.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func selectionTitle(for session: SavedSession) -> String {
        guard let index = selectedIDs.firstIndex(of: session.id) else { return "Seleccionar para comparar" }
        return index == 0 ? "Quitar selección: base" : "Quitar selección: segunda"
    }

    private func toggleSelection(_ session: SavedSession) {
        if let index = selectedIDs.firstIndex(of: session.id) {
            selectedIDs.remove(at: index)
        } else if selectedIDs.count < 2 {
            selectedIDs.append(session.id)
        }
    }

    private func loadComparisonImages() {
        do {
            let store = try SessionHistoryStore.standard()
            var images: [UUID: UIImage] = [:]
            for id in selectedIDs {
                guard let session = sessions.first(where: { $0.id == id }),
                      let data = try store.photo(for: session) else { continue }
                guard let image = UIImage(data: data) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                images[id] = image
            }
            comparisonImages = images
        } catch {
            comparisonImages = [:]
            self.error = "No se pudieron leer las imágenes: \(error.localizedDescription)"
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
            selectedIDs.removeAll { $0 == session.id }
        } catch {
            self.error = "No se pudo eliminar la sesión: \(error.localizedDescription)"
        }
    }
}
