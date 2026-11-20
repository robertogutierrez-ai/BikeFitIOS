import XCTest
@testable import BikeFitIOS

final class CleatHistoryStoreTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var store: CleatHistoryStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "CleatHistoryStoreTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        store = CleatHistoryStore(defaults: defaults)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        try super.tearDownWithError()
    }

    func testSaveTrimsTextClampsComfortAndKeepsOnlyTenEntries() throws {
        for index in 0..<11 {
            try store.save(
                left: measurement(Double(index)),
                right: measurement(Double(index + 1)),
                note: "  nota \(index)  ",
                comfort: 8,
                symptom: "  dolor  "
            )
        }

        let history = try store.load()
        XCTAssertEqual(history.count, 10)
        XCTAssertEqual(history.first?.note, "nota 10")
        XCTAssertEqual(history.first?.symptom, "dolor")
        XCTAssertEqual(history.first?.comfort, 5)
        XCTAssertEqual(history.last?.note, "nota 1")
    }

    func testDeleteRemovesOnlySelectedEntry() throws {
        try store.save(left: measurement(1), right: measurement(2), note: "", comfort: 3, symptom: "")
        try store.save(left: measurement(3), right: measurement(4), note: "", comfort: 3, symptom: "")
        let history = try store.load()

        let remaining = try store.delete(id: try XCTUnwrap(history.first?.id))

        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.left.rotationDegrees, 1)
    }

    func testInvalidStoredDataIsReported() {
        defaults.set(Data([0x00]), forKey: "bikefit.cleat-history.v1")
        XCTAssertThrowsError(try store.load())
    }

    private func measurement(_ rotation: Double) -> CleatMeasurement {
        CleatMeasurement(
            rotationDegrees: rotation,
            lateralRelativeToShoe: 0.1,
            longitudinalRelativeToShoe: 0.2
        )
    }
}
