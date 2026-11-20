import SwiftUI

struct ReferenceProfilesView: View {
    let onClose: () -> Void
    @State private var profiles: [ReferenceProfile] = []
    @State private var activeID: UUID?
    @State private var editingID: UUID?
    @State private var name = ""
    @State private var minimums: [JointAngle: String] = [:]
    @State private var maximums: [JointAngle: String] = [:]
    @State private var error: String?
    @State private var pendingDeletion: ReferenceProfile?
    @State private var loaded = false
    private let store = ReferenceProfileStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Perfiles y referencias").font(.title2.bold())
                Text("Los rangos los introduce el usuario. Son solo referencias, no objetivos clínicos ni recomendaciones de ajuste. Los valores de Android no se importan automáticamente porque las mediciones pueden diferir.")
                    .foregroundStyle(.secondary)
                if editingID != nil {
                    editor
                } else {
                    if loaded && profiles.isEmpty {
                        Text("No hay perfiles guardados.")
                    }
                    ForEach(profiles) { profile in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(profile.name + (activeID == profile.id ? " · activo" : ""))
                                .font(.headline)
                            ForEach(JointAngle.allCases, id: \.self) { angle in
                                if let range = profile.ranges[angle] {
                                    Text("\(angle.rawValue): \(String(format: "%.1f° – %.1f°", range.minimum, range.maximum))")
                                }
                            }
                            Button(activeID == profile.id ? "Desactivar" : "Activar") {
                                setActive(activeID == profile.id ? nil : profile.id)
                            }
                            Button("Editar") { edit(profile) }
                            Button("Eliminar", role: .destructive) { pendingDeletion = profile }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                    Button("Crear perfil") {
                        editingID = UUID()
                        name = ""
                        minimums = [:]
                        maximums = [:]
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!loaded)
                    Button("Volver", action: onClose)
                }
            }
            .padding()
        }
        .onAppear(perform: reload)
        .confirmationDialog("¿Eliminar este perfil?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                if let profile = pendingDeletion { delete(profile) }
                pendingDeletion = nil
            }
            Button("Cancelar", role: .cancel) { pendingDeletion = nil }
        }
        .alert("Perfiles", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Nombre del perfil", text: $name)
                .textFieldStyle(.roundedBorder)
            Text("Deja ambos campos vacíos para omitir una métrica. Ángulos en grados.")
                .font(.footnote)
            ForEach(JointAngle.allCases, id: \.self) { angle in
                VStack(alignment: .leading) {
                    Text(angle.rawValue).font(.headline)
                    HStack {
                        TextField("Mínimo", text: field(for: angle, isMinimum: true))
                        TextField("Máximo", text: field(for: angle, isMinimum: false))
                    }
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                }
            }
            Button("Guardar perfil") { save() }
                .buttonStyle(.borderedProminent)
            Button("Cancelar") { editingID = nil }
        }
    }

    private func field(for angle: JointAngle, isMinimum: Bool) -> Binding<String> {
        Binding(
            get: { (isMinimum ? minimums : maximums)[angle] ?? "" },
            set: { value in
                if isMinimum { minimums[angle] = value } else { maximums[angle] = value }
            }
        )
    }

    private func edit(_ profile: ReferenceProfile) {
        editingID = profile.id
        name = profile.name
        minimums = profile.ranges.mapValues { String($0.minimum) }
        maximums = profile.ranges.mapValues { String($0.maximum) }
    }

    private func save() {
        guard let id = editingID else { return }
        do {
            var ranges: [JointAngle: AngleRange] = [:]
            for angle in JointAngle.allCases {
                let minText = (minimums[angle] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let maxText = (maximums[angle] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if minText.isEmpty && maxText.isEmpty { continue }
                guard let minimum = Double(minText.replacingOccurrences(of: ",", with: ".")),
                      let maximum = Double(maxText.replacingOccurrences(of: ",", with: ".")) else {
                    throw ReferenceProfileError.invalidRange(angle.rawValue)
                }
                ranges[angle] = AngleRange(minimum: minimum, maximum: maximum)
            }
            try store.save(id: id, name: name, ranges: ranges)
            editingID = nil
            reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func reload() {
        do {
            profiles = try store.profiles()
            activeID = try store.active()?.id
            loaded = true
        } catch {
            loaded = false
            self.error = "No se pudieron leer los perfiles: \(error.localizedDescription)"
        }
    }

    private func setActive(_ id: UUID?) {
        do {
            try store.setActive(id)
            reload()
        } catch {
            self.error = "No se pudo seleccionar el perfil: \(error.localizedDescription)"
        }
    }

    private func delete(_ profile: ReferenceProfile) {
        do {
            try store.delete(profile.id)
            reload()
        } catch {
            self.error = "No se pudo eliminar el perfil: \(error.localizedDescription)"
        }
    }
}
