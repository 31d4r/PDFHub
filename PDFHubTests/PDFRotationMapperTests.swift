import XCTest
@testable import PDFHub

final class PDFRotationMapperTests: XCTestCase {
    func testMapsRotationAnglesByURL() {
        let urlA = URL(fileURLWithPath: "/tmp/a.pdf")
        let urlB = URL(fileURLWithPath: "/tmp/b.pdf")
        let pdfs = [
            PDF(pdfURL: urlA, rotationAngle: .ninety),
            PDF(pdfURL: urlB, rotationAngle: .oneEighty)
        ]

        let mapped = PDFRotationMapper.mapRotationAngles(
            urls: [urlA, urlB],
            from: pdfs
        )

        XCTAssertEqual(mapped[urlA], 90)
        XCTAssertEqual(mapped[urlB], 180)
    }

    func testMissingPDFDefaultsToZero() {
        let url = URL(fileURLWithPath: "/tmp/missing.pdf")
        let mapped = PDFRotationMapper.mapRotationAngles(
            urls: [url],
            from: []
        )

        XCTAssertEqual(mapped[url], 0)
    }
}
