import Foundation

struct CleatSetup: Codable, Identifiable, Equatable {
    let id: UUID
    let savedAt: Date
    let left: CleatMeasurement
    let right: CleatMeasurement
    let note: String
    let comfort: Int
    let symptom: String

    init(
        id: UUID = UUID(),
        savedAt: Date = Date(),
        left: CleatMeasurement,
        right: CleatMeasurement,
        note: String,
        comfort: Int,
        symptom: String
    ) {
        self.id = id
        self.savedAt = savedAt
        self.left = left
        self.right = right
        self.note = note
        self.comfort = comfort
        self.symptom = symptom
    }
}

extension CleatMeasurement: Codable {}

struct CleatHistoryStore {
    static let maximumEntries = 10

    private let defaults: UserDefaults
    private let storageKey: String

    init(defaults: UserDefaults = .standard, storageKey: String = "bikefit.cleat-history.v1") {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func load() throws -> [CleatSetup] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        return try JSONDecoder().decode([CleatSetup].self, from: data)
    }

    @discardableResult
    func save(
        left: CleatMeasurement,
        right: CleatMeasurement,
        note: String,
        comfort: Int,
        symptom: String
    ) throws -> [CleatSetup] {
        let setup = CleatSetup(
            left: left,
            right: right,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            comfort: min(max(comfort, 1), 5),
            symptom: symptom.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let history = ([setup] + (try load())).prefix(Self.maximumEntries)
        let entries = Array(history)
        defaults.set(try JSONEncoder().encode(entries), forKey: storageKey)
        return entries
    }

    @discardableResult
    func delete(id: UUID) throws -> [CleatSetup] {
        let entries = try load().filter { $0.id != id }
        defaults.set(try JSONEncoder().encode(entries), forKey: storageKey)
        return entries
    }
}
