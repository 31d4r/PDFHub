import BeaverCore
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Beaver

/// Reviewing a scan: pages in order, filters, corners, and saving one PDF.
@MainActor
struct ScanReactorTests {
    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ScanReactorTests-\(UUID().uuidString)")
    private let saveLocation = MockSaveLocationProvider()

    private func makeReactor(date: Date = Date(timeIntervalSince1970: 0)) -> ScanReactor {
        ScanReactor(builder: ScanDocumentBuilder(directory: directory), saveLocationProvider: saveLocation, date: date)
    }

    private func page(_ value: Double = 0.9) -> CGImage {
        ScanImages.make(width: 300, height: 400, background: ScanImages.grey(value))
    }

    private func storedFiles() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    }

    @Test func capturesBecomeEnhancedPagesInOrder() async {
        let reactor = makeReactor()
        await reactor.action(.addCaptures([page(), page(), page()]))

        #expect(reactor.state.pages.count == 3)
        #expect(reactor.state.pages.allSatisfy { $0.filter == .enhanced && $0.quad == .fullImage })
        #expect(reactor.state.currentPageID == reactor.state.pages.first?.id)
        #expect(storedFiles().count == 3)
        #expect(reactor.state.activity == nil)

        await reactor.action(.addCaptures([page()]))
        #expect(reactor.state.currentPageID == reactor.state.pages.last?.id)
        reactor.action(.discard)
    }

    @Test func theNameIsScanAndTheMinute() {
        let date = ISO8601DateFormatter().date(from: "2026-11-04T16:05:00Z")!
        let reactor = ScanReactor(
            builder: ScanDocumentBuilder(directory: directory),
            saveLocationProvider: saveLocation,
            date: date
        )
        let expected = ScanFileName.make(prefix: "Scan", date: date)
        #expect(reactor.state.name == expected)

        reactor.action(.rename("   "))
        #expect(reactor.state.name == expected)
        reactor.action(.rename(" Receipts "))
        #expect(reactor.state.name == "Receipts")
    }

    @Test func onlyUnsavedPagesAskBeforeTheyAreThrownAway() async throws {
        let output = directory.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        saveLocation.saveURL = output.appendingPathComponent("Saved.pdf")
        let reactor = makeReactor()
        #expect(!reactor.state.needsDiscardConfirmation)

        await reactor.action(.addCaptures([page()]))
        #expect(reactor.state.needsDiscardConfirmation)

        await reactor.action(.save)
        #expect(reactor.state.savedURL != nil)
        #expect(!reactor.state.needsDiscardConfirmation)
    }

    @Test func aFilterAppliesToOnePageOrAll() async {
        let reactor = makeReactor()
        await reactor.action(.addCaptures([page(), page()]))
        #expect(!reactor.state.canApplyFilterToAll)

        reactor.action(.setFilter(.blackAndWhite))
        #expect(reactor.state.pages.map(\.filter) == [.blackAndWhite, .enhanced])
        #expect(reactor.state.canApplyFilterToAll)

        reactor.action(.applyFilterToAll)
        #expect(reactor.state.pages.map(\.filter) == [.blackAndWhite, .blackAndWhite])
        #expect(!reactor.state.canApplyFilterToAll)
        reactor.action(.discard)
    }

    @Test func rotatesAndReordersPages() async throws {
        let reactor = makeReactor()
        await reactor.action(.addCaptures([page(), page(), page()]))
        let ids = reactor.state.pages.map(\.id)

        reactor.action(.rotate(id: ids[1], direction: .right))
        reactor.action(.rotate(id: ids[1], direction: .right))
        #expect(reactor.state.pages[1].rotation == .oneEighty)
        reactor.action(.rotate(id: ids[0], direction: .left))
        #expect(reactor.state.pages[0].rotation == .twoSeventy)

        reactor.action(.move(fromOffsets: IndexSet(integer: 2), toOffset: 0))
        #expect(reactor.state.pages.map(\.id) == [ids[2], ids[0], ids[1]])
        reactor.action(.discard)
    }

    @Test func onlyAPageShapeIsAcceptedAsCorners() async throws {
        let reactor = makeReactor()
        await reactor.action(.addCaptures([page()]))
        let id = try #require(reactor.state.pages.first?.id)

        let crossed = DocumentQuad.fullImage.moving(.topLeft, to: CGPoint(x: 1, y: 0))
        reactor.action(.setQuad(crossed, id: id))
        #expect(reactor.state.pages[0].quad == .fullImage)

        let inset = DocumentQuad.fullImage.moving(.topLeft, to: CGPoint(x: 0.1, y: 0.9))
        reactor.action(.setQuad(inset, id: id))
        #expect(reactor.state.pages[0].quad == inset)
        reactor.action(.discard)
    }

    @Test func deletingShowsTheNextPageAndRemovesThePhoto() async {
        let reactor = makeReactor()
        await reactor.action(.addCaptures([page(), page(), page()]))
        let ids = reactor.state.pages.map(\.id)

        reactor.action(.showPage(ids[1]))
        reactor.action(.delete([ids[1]]))
        #expect(reactor.state.pages.map(\.id) == [ids[0], ids[2]])
        #expect(reactor.state.currentPageID == ids[2])
        #expect(storedFiles().count == 2)

        reactor.action(.delete([ids[2]]))
        #expect(reactor.state.currentPageID == ids[0])
        reactor.action(.delete([ids[0]]))
        #expect(reactor.state.currentPageID == nil)
        #expect(!reactor.state.canSave)
        #expect(storedFiles().isEmpty)
    }

    @Test func retakeKeepsThePlaceAndTheFilter() async throws {
        let reactor = makeReactor()
        await reactor.action(.addCaptures([page(), page()]))
        let id = reactor.state.pages[1].id
        let oldURL = reactor.state.pages[1].imageURL
        reactor.action(.showPage(id))
        reactor.action(.setFilter(.grayscale))
        reactor.action(.rotate(id: id, direction: .right))

        await reactor.action(.retake(id: id, with: page(0.5)))
        #expect(reactor.state.pages[1].id == id)
        #expect(reactor.state.pages[1].imageURL != oldURL)
        #expect(reactor.state.pages[1].filter == .grayscale)
        #expect(reactor.state.pages[1].rotation == .zero)
        #expect(!FileManager.default.fileExists(atPath: oldURL.path))
        reactor.action(.discard)
    }

    @Test func photosWithoutAPageUseTheWholePhoto() async throws {
        let reactor = makeReactor()
        let photos = directory.appendingPathComponent("Photos", isDirectory: true)
        try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let photo = photos.appendingPathComponent("photo.png")
        let destination = try #require(CGImageDestinationCreateWithURL(photo as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, page(0.5), nil)
        #expect(CGImageDestinationFinalize(destination))
        let missing = photos.appendingPathComponent("missing.jpg")

        await reactor.action(.addPhotos([photo, missing]))
        #expect(reactor.state.pages.count == 1)
        #expect(reactor.state.pages.first?.quad == .fullImage)
        #expect(reactor.state.errorMessage == DesignSystem.Scan.pagesFailed(1))
        reactor.action(.didDismissError)
        #expect(reactor.state.errorMessage == nil)
        reactor.action(.discard)
    }

    @Test func savesOnePDFUnderTheNameAndCleansUp() async throws {
        let output = directory.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        saveLocation.saveURL = output.appendingPathComponent("Receipts.pdf")
        let reactor = makeReactor()
        await reactor.action(.addCaptures([page(), page()]))
        reactor.action(.rename("Receipts"))

        await reactor.action(.save)
        let url = try #require(reactor.state.savedURL)
        #expect(saveLocation.requestedNames == ["Receipts.pdf"])
        #expect(CGPDFDocument(url as CFURL)?.numberOfPages == 2)
        #expect(storedFiles() == ["out"])
        #expect(!reactor.state.canEdit)
    }

    @Test func aFailedSaveKeepsThePages() async {
        saveLocation.saveURL = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)/Scan.pdf")
        let reactor = makeReactor()
        await reactor.action(.addCaptures([page()]))

        await reactor.action(.save)
        #expect(reactor.state.savedURL == nil)
        #expect(reactor.state.errorMessage == DesignSystem.Scan.saveFailed)
        #expect(reactor.state.pages.count == 1)
        #expect(reactor.state.needsDiscardConfirmation)
        #expect(reactor.state.canSave)
        reactor.action(.discard)
    }
}

/// A saved scan joins the workspace and the banner offers to share it.
@MainActor
struct AddScanTests {
    @Test func aSavedScanIsAddedAndOffered() async {
        let reactor = BeaverReactor(
            saveLocationProvider: MockSaveLocationProvider(),
            imageService: MockImageService(),
            exportService: MockExportService(result: .cancelled)
        )
        await reactor.action(.addScan(TestFixtures.samplePDF))

        #expect(reactor.state.items.map(\.url) == [TestFixtures.samplePDF])
        #expect(reactor.state.exportAlert?.isSuccess == true)
        #expect(reactor.state.exportAlert?.output == TestFixtures.samplePDF)
        #expect(reactor.state.exportToAdd == nil)
    }
}
