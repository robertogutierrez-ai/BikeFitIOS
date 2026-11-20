import XCTest
@testable import BikeFitIOS

final class ReferenceProfileStoreTests: XCTestCase {
    func testSaveActivateUpdateAndDeleteProfile() throws {
        let suite = "ReferenceProfileTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ReferenceProfileStore(defaults: defaults)
        let id = UUID()
        try store.save(id: id, name: "  Mi perfil  ", ranges: [.knee: AngleRange(minimum: 10, maximum: 30)])
        try store.setActive(id)
        XCTAssertEqual(try store.active()?.name, "Mi perfil")
        try store.save(id: id, name: "Nuevo nombre", ranges: [.knee: AngleRange(minimum: 12, maximum: 32)])
        XCTAssertEqual(try store.active()?.ranges[.knee]?.minimum, 12)
        try store.delete(id)
        XCTAssertNil(try store.active())
        XCTAssertTrue(try store.profiles().isEmpty)
    }

    func testInvalidRangesAndDuplicateNamesAreRejected() throws {
        let suite = "ReferenceProfileTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ReferenceProfileStore(defaults: defaults)
        let id = UUID()
        try store.save(id: id, name: "Perfil", ranges: [.knee: AngleRange(minimum: 0, maximum: 180)])
        XCTAssertThrowsError(try store.save(id: UUID(), name: "perfil", ranges: [.knee: AngleRange(minimum: 0, maximum: 1)]))
        XCTAssertThrowsError(try store.save(id: id, name: "Perfil", ranges: [.knee: AngleRange(minimum: 20, maximum: 10)]))
        XCTAssertThrowsError(try store.save(id: id, name: "Perfil", ranges: [.knee: AngleRange(minimum: Double.nan, maximum: 10)]))
        XCTAssertThrowsError(try store.save(id: id, name: "Perfil", ranges: [:]))
        XCTAssertThrowsError(try store.setActive(UUID()))
        XCTAssertEqual(try store.profiles().first?.ranges[.knee]?.maximum, 180)
    }

    func testInvalidStoredDataIsReported() throws {
        let suite = "ReferenceProfileTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data([0]), forKey: "bikefit.reference-profiles.v1")
        XCTAssertThrowsError(try ReferenceProfileStore(defaults: defaults).profiles())
        defaults.set("formato incorrecto", forKey: "bikefit.reference-profiles.v1")
        XCTAssertThrowsError(try ReferenceProfileStore(defaults: defaults).profiles())
    }

    func testExtendedProfileAndLegacyDecoding() throws {
        let legacy = Data("""
        {"id":"00000000-0000-0000-0000-000000000001","name":"Anterior","ranges":[]}
        """.utf8)
        XCTAssertNil(try JSONDecoder().decode(ReferenceProfile.self, from: legacy).bikes)
        let suite = "ReferenceProfileTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ReferenceProfileStore(defaults: defaults)
        let id = UUID()
        let bike = ProfileBike(id: UUID(), name: "Ruta", type: "Carretera", saddleHeightMM: 720, reachMM: nil)
        try store.save(id: id, name: "Perfil", ranges: [.knee: AngleRange(minimum: 10, maximum: 30)],
                       discipline: "Carretera", inseamCM: 80, crankMM: 170, flexibility: "Normal", bikes: [bike])
        let restored = try XCTUnwrap(store.profiles().first)
        XCTAssertEqual(restored.discipline, "Carretera")
        XCTAssertEqual(restored.inseamCM, 80)
        XCTAssertEqual(restored.bikes?.first?.saddleHeightMM, 720)
        XCTAssertThrowsError(try store.save(id: id, name: "Perfil", ranges: restored.ranges, inseamCM: -.infinity))
        XCTAssertThrowsError(try store.save(id: id, name: "Perfil", ranges: restored.ranges,
                                            bikes: [bike, bike]))
        XCTAssertEqual(try store.profiles().first?.bikes?.count, 1)
        try store.save(id: id, name: "Perfil", ranges: [:], bikes: [bike])
        XCTAssertTrue(try XCTUnwrap(store.profiles().first).ranges.isEmpty)
        XCTAssertThrowsError(try store.save(id: id, name: "Perfil", ranges: [:], inseamCM: -1))
    }
}
