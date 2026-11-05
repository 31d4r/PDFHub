import AppKit
import XCTest
@testable import Beaver

@MainActor
final class BeaverReactorTests: XCTestCase {
    func testAddPDFsDeduplicatesAndNavigates() async {
        let reactor = BeaverReactor(
            filePanelService: MockFilePanelService(),
            imageService: MockImageService()
        )
        let url = TestFixtures.samplePDF

        await reactor.action(.addPDFs([url, url]))

        XCTAssertEqual(reactor.state.selectedPDFs.count, 1)
        XCTAssertEqual(reactor.state.selectedPDFs.first?.pdfURL, url)
        XCTAssertEqual(reactor.state.screen, .pdfWorkflow)
    }

    func testDeletePDFReturnsToMenuWhenEmpty() async {
        let reactor = BeaverReactor(
            filePanelService: MockFilePanelService(),
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
        let image = NSImage(size: NSSize(width: 10, height: 10))
        imageService.imagesByURL[TestFixtures.samplePNG] = image

        let reactor = BeaverReactor(
            filePanelService: MockFilePanelService(),
            imageService: imageService
        )

        await reactor.action(.addImages([TestFixtures.samplePNG, TestFixtures.samplePNG]))

        XCTAssertEqual(reactor.state.selectedImages.count, 1)
        XCTAssertEqual(reactor.state.selectedImages.first?.url, TestFixtures.samplePNG)
        XCTAssertEqual(reactor.state.screen, .imageWorkflow)
    }

    func testDeleteImageByID() async {
        let imageService = MockImageService()
        let first = NSImage(size: NSSize(width: 10, height: 10))
        let second = NSImage(size: NSSize(width: 12, height: 12))
        let firstURL = TestFixtures.samplePNG
        let secondURL = URL(fileURLWithPath: "/tmp/second.png")
        imageService.imagesByURL[firstURL] = first
        imageService.imagesByURL[secondURL] = second

        let reactor = BeaverReactor(
            filePanelService: MockFilePanelService(),
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
            filePanelService: MockFilePanelService(),
            imageService: MockImageService()
        )
        await reactor.action(.addPDFs([TestFixtures.samplePDF]))

        await reactor.action(.goBack)

        XCTAssertTrue(reactor.state.selectedPDFs.isEmpty)
        XCTAssertEqual(reactor.state.screen, .menu)
    }
}
