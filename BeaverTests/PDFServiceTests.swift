import PDFKit
import XCTest
@testable import Beaver

final class PDFServiceTests: XCTestCase {
    private let service = PDFService()

    func testLoadPDF() {
        let document = service.loadPDF(from: TestFixtures.samplePDF)
        XCTAssertNotNil(document)
        XCTAssertEqual(document?.pageCount, 2)
    }

    func testMergePDFsCombinesPagesAndAppliesRotation() {
        let urls = [TestFixtures.samplePDF, TestFixtures.sample2PDF]
        let rotationAngles = [
            TestFixtures.samplePDF: 90,
            TestFixtures.sample2PDF: 180
        ]

        let merged = service.mergePDFs(
            urls: urls,
            rotationAngles: rotationAngles
        )

        XCTAssertEqual(merged?.pageCount, 3)
        XCTAssertEqual(merged?.page(at: 0)?.rotation, 90)
        XCTAssertEqual(merged?.page(at: 2)?.rotation, 180)
    }

    func testSplitPDFCreatesOneDocumentPerPage() {
        let split = service.splitPDF(
            urls: [TestFixtures.samplePDF],
            rotationAngles: [TestFixtures.samplePDF: 270]
        )

        XCTAssertEqual(split.count, 2)
        XCTAssertEqual(split[0].document.pageCount, 1)
        XCTAssertEqual(split[0].document.page(at: 0)?.rotation, 270)
    }

    func testMergeEmptyURLsReturnsNil() {
        XCTAssertNil(service.mergePDFs(urls: [], rotationAngles: [:]))
    }
}
