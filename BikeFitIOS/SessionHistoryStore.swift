import Foundation

struct SavedSession: Codable, Identifiable {
    let id: UUID
    let savedAt: Date
    let result: VideoAnalysisResult

    init(id: UUID = UUID(), savedAt: Date = Date(), result: VideoAnalysisResult) {
        self.id = id
        self.savedAt = savedAt
        self.result = result
    }
}

struct SessionHistoryStore {
    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    static func standard() throws -> SessionHistoryStore {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        return SessionHistoryStore(directory: support.appendingPathComponent("BikeFitSessions", isDirectory: true))
    }

    func load() throws -> [SavedSession] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        return try files.map { url in
            try JSONDecoder().decode(SavedSession.self, from: Data(contentsOf: url))
        }.sorted { $0.savedAt > $1.savedAt }
    }

    func save(_ result: VideoAnalysisResult) throws -> SavedSession {
        let session = SavedSession(result: result)
        let data = try JSONEncoder().encode(session)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url(for: session.id), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return session
    }

    func delete(_ session: SavedSession) throws {
        try deletePhoto(session)
        try FileManager.default.removeItem(at: url(for: session.id))
    }

    func photo(for session: SavedSession) throws -> Data? {
        let photo = photoURL(for: session.id)
        guard FileManager.default.fileExists(atPath: photo.path) else { return nil }
        return try Data(contentsOf: photo)
    }

    func savePhoto(_ data: Data, for session: SavedSession) throws {
        guard FileManager.default.fileExists(atPath: url(for: session.id).path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        try data.write(to: photoURL(for: session.id), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func deletePhoto(_ session: SavedSession) throws {
        let photo = photoURL(for: session.id)
        if FileManager.default.fileExists(atPath: photo.path) {
            try FileManager.default.removeItem(at: photo)
        }
    }

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }

    private func photoURL(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString).appendingPathExtension("jpg")
    }
}
