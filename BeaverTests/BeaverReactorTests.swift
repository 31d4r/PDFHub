import BeaverCore
import AppKit
import XCTest
@testable import Beaver

@MainActor
final class BeaverReactorTests: XCTestCase {
    func testAddPDFsDeduplicatesAndNavigates() async {
        let reactor = BeaverReactor(
            saveLocationProvider: MockSaveLocationProvider(),
            imageService: MockImageService()
        )
        let url = TestFixtures.samplePDF

        await reactor.action(.addPDFs([url, url]))

        XCTAssertEqual(reactor.state.selectedPDFs.count, 1)
        XCTAssertEqual(reactor.state.selectedPDFs.first?.url, url)
        XCTAssertEqual(reactor.state.screen, .pdfWorkflow)
    }

    func testDeletePDFReturnsToMenuWhenEmpty() async {
        let reactor = BeaverReactor(
            saveLocationProvider: MockSaveLocationProvider(),
            imageService: MockImageService()
        )
        await reactor.action(.addPDFs([TestFixtures.samplePDF]))
        let id = reactor.state.selectedPDFs[0].id

        await reactor.action(.deletePDF(id))

        XCTAssertTrue(reactor.state.selectedPDFs.isEmpty)
        XCTAssertEqual(reactor.state.screen, .menu)
    }

    func testAddImagesUsesImageServiceAndNavigates() async {
        let imageService = MockImageService()
        imageService.thumbnailsByURL[TestFixtures.samplePNG] = TestImages.solid(width: 10, height: 10)

        let reactor = BeaverReactor(
            saveLocationProvider: MockSaveLocationProvider(),
            imageService: imageService
        )

        await reactor.action(.addImages([TestFixtures.samplePNG, TestFixtures.samplePNG]))

        XCTAssertEqual(reactor.state.selectedImages.count, 1)
        XCTAssertEqual(reactor.state.selectedImages.first?.url, TestFixtures.samplePNG)
        XCTAssertEqual(reactor.state.screen, .imageWorkflow)
    }

    func testDeleteImageByID() async {
        let imageService = MockImageService()
        let first = TestImages.solid(width: 10, height: 10)
        let second = TestImages.solid(width: 12, height: 12)
        let firstURL = TestFixtures.samplePNG
        let secondURL = URL(fileURLWithPath: "/tmp/second.png")
        imageService.thumbnailsByURL[firstURL] = first
        imageService.thumbnailsByURL[secondURL] = second

        let reactor = BeaverReactor(
            saveLocationProvider: MockSaveLocationProvider(),
            imageService: imageService
        )
        await reactor.action(.addImages([firstURL, secondURL]))
        let firstID = reactor.state.selectedImages[0].id

        await reactor.action(.deleteImage(firstID))

        XCTAssertEqual(reactor.state.selectedImages.count, 1)
        XCTAssertEqual(reactor.state.selectedImages.first?.url, secondURL)
        XCTAssertEqual(reactor.state.screen, .imageWorkflow)
    }

    func testGoBackClearsPDFWorkflow() async {
        let reactor = BeaverReactor(
            saveLocationProvider: MockSaveLocationProvider(),
            imageService: MockImageService()
        )
        await reactor.action(.addPDFs([TestFixtures.samplePDF]))

        await reactor.action(.goBack)

        XCTAssertTrue(reactor.state.selectedPDFs.isEmpty)
        XCTAssertEqual(reactor.state.screen, .menu)
    }
}
