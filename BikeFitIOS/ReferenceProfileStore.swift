import Foundation

struct ReferenceProfile: Codable, Identifiable {
    let id: UUID
    let name: String
    let ranges: [JointAngle: AngleRange]
}

private struct ReferenceProfiles: Codable {
    var profiles: [ReferenceProfile]
    var activeID: UUID?
}

enum ReferenceProfileError: LocalizedError {
    case invalidName
    case duplicateName
    case invalidRange(String)
    case emptyRanges
    case missingProfile
    case invalidStorage

    var errorDescription: String? {
        switch self {
        case .invalidName: return "Escribe un nombre de entre 1 y 50 caracteres."
        case .duplicateName: return "Ya existe un perfil con ese nombre."
        case .invalidRange(let angle): return "Revisa los valores de \(angle): deben estar entre 0° y 180°, con mínimo menor o igual al máximo."
        case .emptyRanges: return "Introduce al menos un rango de referencia."
        case .missingProfile: return "El perfil seleccionado ya no existe."
        case .invalidStorage: return "Los datos guardados no tienen el formato esperado."
        }
    }
}

struct ReferenceProfileStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "bikefit.reference-profiles.v1") {
        self.defaults = defaults
        self.key = key
    }

    func profiles() throws -> [ReferenceProfile] {
        try read().profiles
    }

    func active() throws -> ReferenceProfile? {
        let state = try read()
        guard let id = state.activeID else { return nil }
        guard let profile = state.profiles.first(where: { $0.id == id }) else {
            throw ReferenceProfileError.missingProfile
        }
        return profile
    }

    func save(id: UUID, name: String, ranges: [JointAngle: AngleRange]) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 50 else { throw ReferenceProfileError.invalidName }
        guard !ranges.isEmpty else { throw ReferenceProfileError.emptyRanges }
        for (angle, range) in ranges {
            guard range.minimum.isFinite, range.maximum.isFinite,
                  range.minimum >= 0, range.maximum <= 180,
                  range.minimum <= range.maximum else {
                throw ReferenceProfileError.invalidRange(angle.rawValue)
            }
        }
        var state = try read()
        guard !state.profiles.contains(where: {
            $0.id != id && $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) else { throw ReferenceProfileError.duplicateName }
        let profile = ReferenceProfile(id: id, name: name, ranges: ranges)
        if let index = state.profiles.firstIndex(where: { $0.id == id }) {
            state.profiles[index] = profile
        } else {
            state.profiles.append(profile)
        }
        try write(state)
    }

    func setActive(_ id: UUID?) throws {
        var state = try read()
        if let id = id, !state.profiles.contains(where: { $0.id == id }) {
            throw ReferenceProfileError.missingProfile
        }
        state.activeID = id
        try write(state)
    }

    func delete(_ id: UUID) throws {
        var state = try read()
        guard state.profiles.contains(where: { $0.id == id }) else {
            throw ReferenceProfileError.missingProfile
        }
        state.profiles.removeAll { $0.id == id }
        if state.activeID == id { state.activeID = nil }
        try write(state)
    }

    private func read() throws -> ReferenceProfiles {
        guard let value = defaults.object(forKey: key) else {
            return ReferenceProfiles(profiles: [], activeID: nil)
        }
        guard let data = value as? Data else { throw ReferenceProfileError.invalidStorage }
        return try JSONDecoder().decode(ReferenceProfiles.self, from: data)
    }

    private func write(_ state: ReferenceProfiles) throws {
        defaults.set(try JSONEncoder().encode(state), forKey: key)
    }
}
