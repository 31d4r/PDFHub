import BeaverCore
import PDFKit
import XCTest
@testable import Beaver

final class PDFFileWriterServiceTests: XCTestCase {
    func testSavePDFDocumentWritesData() throws {
        let mockIO = MockFileIOService()
        let writer = PDFFileWriterService(fileIOService: mockIO)
        let document = PDFDocument(url: TestFixtures.samplePDF)!
        let destination = URL(fileURLWithPath: "/tmp/beaver-test-output.pdf")

        try writer.savePDFDocument(document, to: destination)

        XCTAssertEqual(mockIO.writtenURLs, [destination])
    }

    func testSavePDFDocumentsReturnsCounts() {
        let mockIO = MockFileIOService()
        let writer = PDFFileWriterService(fileIOService: mockIO)
        let pages = [
            SplitPage(document: PDFDocument(url: TestFixtures.samplePDF)!, fileName: "a_page-1.pdf"),
            SplitPage(document: PDFDocument(url: TestFixtures.sample2PDF)!, fileName: "b_page-1.pdf")
        ]
        let directory = URL(fileURLWithPath: "/tmp")

        let result = writer.savePDFDocuments(
            pages,
            to: directory
        )

        XCTAssertEqual(result.successCount, 2)
        XCTAssertEqual(result.failureCount, 0)
        XCTAssertTrue(result.isCompleteSuccess)
        XCTAssertEqual(mockIO.writtenURLs.count, 2)
    }

    func testSavePDFDocumentsTracksFailures() {
        let mockIO = MockFileIOService()
        mockIO.shouldFail = true
        let writer = PDFFileWriterService(fileIOService: mockIO)
        let pages = [SplitPage(document: PDFDocument(url: TestFixtures.samplePDF)!, fileName: "a_page-1.pdf")]

        let result = writer.savePDFDocuments(
            pages,
            to: URL(fileURLWithPath: "/tmp")
        )

        XCTAssertEqual(result.successCount, 0)
        XCTAssertEqual(result.failureCount, 1)
        XCTAssertTrue(result.isCompleteFailure)
    }
}
