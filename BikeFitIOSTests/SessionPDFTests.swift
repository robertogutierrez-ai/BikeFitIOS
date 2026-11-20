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

    func testExtendedReportIncludesAllPagesAndAISummary() throws {
        let result = VideoAnalysisResult(
            ranges: [.knee: AngleRange(minimum: 10, maximum: 25)],
            validFrames: 2, sampledFrames: 2, side: "izquierdo",
            timeline: [AngleSample(time: 0, angles: [.knee: 10]), AngleSample(time: 1, angles: [.knee: 20])],
            estimatedCycles: 3
        )
        let summary = Array(repeating: "Resumen experimental de la medición.", count: 100).joined(separator: " ")
        let document = try XCTUnwrap(PDFDocument(data: SessionPDF.make(result: result, date: Date(), aiSummary: summary)))
        XCTAssertGreaterThan(document.pageCount, 1)
        let contents = try XCTUnwrap(document.string)
        XCTAssertTrue(contents.contains("Ciclos aproximados: 3"))
        XCTAssertTrue(contents.contains("Media: 15.0"))
        XCTAssertTrue(contents.contains("La IA puede equivocarse"))
        XCTAssertTrue(contents.contains("diagnóstico"))
    }
}
