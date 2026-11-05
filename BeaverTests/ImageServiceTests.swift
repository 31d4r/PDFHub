import XCTest
@testable import Beaver

final class ImageServiceTests: XCTestCase {
    private let service = ImageService()

    func testLoadImage() {
        let image = service.loadImage(from: TestFixtures.samplePNG)
        XCTAssertNotNil(image)
    }

    func testConvertImagesToPDF() {
        let result = service.convertImagesToPDF(
            imageUrls: [TestFixtures.samplePNG]
        )

        XCTAssertEqual(result.document?.pageCount, 1)
        XCTAssertTrue(result.skippedURLs.isEmpty)
    }

    func testConvertInvalidURLsReturnsNil() {
        let missing = URL(fileURLWithPath: "/tmp/does-not-exist.png")
        let result = service.convertImagesToPDF(
            imageUrls: [missing]
        )
        XCTAssertNil(result.document)
        XCTAssertEqual(result.skippedURLs, [missing])
    }
}
