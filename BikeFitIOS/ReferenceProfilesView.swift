import SwiftUI

struct ReferenceProfilesView: View {
    let onClose: () -> Void
    @State private var profiles: [ReferenceProfile] = []
    @State private var activeID: UUID?
    @State private var editingID: UUID?
    @State private var name = ""
    @State private var minimums: [JointAngle: String] = [:]
    @State private var maximums: [JointAngle: String] = [:]
    @State private var discipline = ""
    @State private var inseam = ""
    @State private var crank = ""
    @State private var flexibility = ""
    @State private var bikes: [BikeDraft] = []
    @State private var error: String?
    @State private var pendingDeletion: ReferenceProfile?
    @State private var loaded = false
    private let store = ReferenceProfileStore()

    private struct BikeDraft: Identifiable {
        let id: UUID
        var name: String
        var type: String
        var saddle: String
        var reach: String
    }

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
                            if let discipline = profile.discipline { Text("Disciplina: \(discipline)") }
                            if let inseam = profile.inseamCM { Text("Entrepierna: \(String(format: "%.1f", inseam)) cm") }
                            if let crank = profile.crankMM { Text("Biela: \(String(format: "%.1f", crank)) mm") }
                            if let flexibility = profile.flexibility { Text("Flexibilidad indicada: \(flexibility)") }
                            ForEach(profile.bikes ?? []) { bike in
                                Text("Bicicleta: \(bike.name) · \(bike.type)")
                                if let saddle = bike.saddleHeightMM { Text("Altura de sillín: \(String(format: "%.1f", saddle)) mm") }
                                if let reach = bike.reachMM { Text("Alcance: \(String(format: "%.1f", reach)) mm") }
                            }
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
                        discipline = ""
                        inseam = ""
                        crank = ""
                        flexibility = ""
                        bikes = []
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
            Text("Datos opcionales; no modifican automáticamente los rangos ni las mediciones.")
                .font(.footnote)
            TextField("Disciplina (por ejemplo, carretera)", text: $discipline)
                .textFieldStyle(.roundedBorder)
            TextField("Entrepierna (cm)", text: $inseam)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
            TextField("Longitud de biela (mm)", text: $crank)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
            TextField("Flexibilidad indicada por ti", text: $flexibility)
                .textFieldStyle(.roundedBorder)
            Text("Bicicletas").font(.headline)
            ForEach($bikes) { $bike in
                VStack(alignment: .leading) {
                    TextField("Nombre de la bicicleta", text: $bike.name)
                    TextField("Tipo (por ejemplo, carretera)", text: $bike.type)
                    TextField("Altura de sillín (mm, opcional)", text: $bike.saddle)
                        .keyboardType(.decimalPad)
                    TextField("Alcance (mm, opcional)", text: $bike.reach)
                        .keyboardType(.decimalPad)
                    Button("Eliminar bicicleta", role: .destructive) {
                        bikes.removeAll { $0.id == bike.id }
                    }
                }
                .textFieldStyle(.roundedBorder)
            }
            Button("Añadir bicicleta") {
                bikes.append(BikeDraft(id: UUID(), name: "", type: "", saddle: "", reach: ""))
            }
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
        discipline = profile.discipline ?? ""
        inseam = profile.inseamCM.map { String($0) } ?? ""
        crank = profile.crankMM.map { String($0) } ?? ""
        flexibility = profile.flexibility ?? ""
        bikes = (profile.bikes ?? []).map {
            BikeDraft(id: $0.id, name: $0.name, type: $0.type,
                      saddle: $0.saddleHeightMM.map { String($0) } ?? "",
                      reach: $0.reachMM.map { String($0) } ?? "")
        }
    }

    private func optionalNumber(_ text: String) throws -> Double? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return nil }
        guard let number = Double(value.replacingOccurrences(of: ",", with: ".")) else {
            throw ReferenceProfileError.invalidDetails
        }
        return number
    }

    private func optionalText(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
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
            let savedBikes = try bikes.map { bike in
                ProfileBike(id: bike.id, name: bike.name.trimmingCharacters(in: .whitespacesAndNewlines),
                            type: bike.type.trimmingCharacters(in: .whitespacesAndNewlines),
                            saddleHeightMM: try optionalNumber(bike.saddle), reachMM: try optionalNumber(bike.reach))
            }
            try store.save(id: id, name: name, ranges: ranges, discipline: optionalText(discipline),
                           inseamCM: try optionalNumber(inseam), crankMM: try optionalNumber(crank),
                           flexibility: optionalText(flexibility), bikes: savedBikes)
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
