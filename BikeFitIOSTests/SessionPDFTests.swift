import PDFKit
import XCTest
@testable import BikeFitIOS

final class SessionPDFTests: XCTestCase {
    func testReportContainsMeasuredResultsAndWarning() throws {
        let result = VideoAnalysisResult(
            ranges: [.knee: AngleRange(minimum: 10, maximum: 25)],
            validFrames: 5, sampledFrames: 8, side: "izquierdo"
        )
        let data = SessionPDF.make(result: result, date: Date(timeIntervalSince1970: 0))
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(document.pageCount, 1)
        let contents = try XCTUnwrap(document.string)
        XCTAssertTrue(contents.contains("Rodilla"))
        XCTAssertTrue(contents.contains("10.0"))
        XCTAssertTrue(contents.contains("25.0"))
        XCTAssertTrue(contents.contains("5 de 8"))
        XCTAssertTrue(contents.contains("diagnóstico"))
        XCTAssertFalse(contents.contains("Cadera"))
    }
}
