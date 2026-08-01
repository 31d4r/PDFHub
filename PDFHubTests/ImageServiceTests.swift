import XCTest
@testable import PDFHub

final class ImageServiceTests: XCTestCase {
    private let service = ImageService()

    func testLoadImage() {
        let image = service.loadImage(from: TestFixtures.samplePNG)
        XCTAssertNotNil(image)
    }

    func testConvertImagesToPDF() {
        let document = service.convertImagesToPDF(
            imageUrls: [TestFixtures.samplePNG]
        )

        XCTAssertEqual(document?.pageCount, 1)
    }

    func testConvertInvalidURLsReturnsNil() {
        let document = service.convertImagesToPDF(
            imageUrls: [URL(fileURLWithPath: "/tmp/does-not-exist.png")]
        )
        XCTAssertNil(document)
    }
}
