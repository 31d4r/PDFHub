import BeaverCore
import XCTest
@testable import Beaver

final class ImageServiceTests: XCTestCase {
    private let service = ImageService()

    func testThumbnail() {
        let image = service.thumbnail(for: TestFixtures.samplePNG, maxPixelSize: 800)
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
