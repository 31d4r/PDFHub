import BeaverCore
import Foundation
import PDFKit
import Testing
@testable import Beaver

/// Writes a copy of `source` whose pages carry the given saved rotations (by page index).
private func makePDF(from source: URL = TestFixtures.samplePDF, savedRotations: [Int: Int]) throws -> URL {
    let document = try #require(PDFDocument(url: source))
    for (index, rotation) in savedRotations {
        document.page(at: index)?.rotation = rotation
    }
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("beaver-pages-\(UUID().uuidString).pdf")
    #expect(document.write(to: url))
    return url
}

private func pageCount(_ url: URL) throws -> Int {
    try #require(PDFDocument(url: url)).pageCount
}

@Suite("PDF rotation model")
struct PDFRotationModelTests {
    @Test("Saved, file and page rotations add up, mod 360", arguments: [
        (0, RotationAngle.zero, RotationAngle.zero, 0),
        (90, .ninety, .zero, 180),
        (90, .ninety, .oneEighty, 0),
        (270, .oneEighty, .twoSeventy, 0),
        (180, .zero, .ninety, 270),
        (-90, .zero, .ninety, 0),
    ])
    func composition(saved: Int, file: RotationAngle, page: RotationAngle, expected: Int) {
        let rotation = PDFRotation(file: file, pages: [0: page])
        #expect(rotation.degrees(forPage: 0, savedRotation: saved) == expected)
        #expect(rotation.degrees(forPage: 1, savedRotation: saved) == RotationAngle.normalized(saved + file.degrees))
    }

    @Test("Upright pages and negative indexes are not stored")
    func dropsUprightPages() {
        let rotation = PDFRotation(file: .ninety, pages: [0: .zero, 1: .ninety, -1: .ninety])
        #expect(rotation.pages == [1: .ninety])
        #expect(rotation.userRotation(forPage: 1) == .oneEighty)
        #expect(rotation.userRotation(forPage: 0) == .ninety)
    }

    @Test("Rotating pages turns each once and forgets pages that come back upright")
    func rotatePages() {
        var item = PDFItem(url: TestFixtures.samplePDF)
        item.rotatePages([0, 2, 2], .right)
        #expect(item.pageRotations == [0: .ninety, 2: .ninety])
        #expect(item.hasPageRotations)

        item.rotatePages([0], .left)
        #expect(item.pageRotations == [2: .ninety])

        item.rotatePages([2], .left)
        #expect(!item.hasPageRotations)
        #expect(item.rotationAngle == .zero)
    }

    @Test("A PDF's rotation round-trips through its item")
    func itemRotation() {
        var item = PDFItem(url: TestFixtures.samplePDF)
        item.rotation = PDFRotation(file: .oneEighty, pages: [1: .twoSeventy])
        #expect(item.rotationAngle == .oneEighty)
        #expect(item.pageRotations == [1: .twoSeventy])
        #expect(item.rotation == PDFRotation(file: .oneEighty, pages: [1: .twoSeventy]))
    }

    @Test("The mapper keeps URL order, the first match wins, unknown URLs get none")
    func mapper() {
        let first = PDFItem(url: TestFixtures.samplePDF, rotationAngle: .ninety, pageRotations: [0: .ninety])
        let duplicate = PDFItem(url: TestFixtures.samplePDF, rotationAngle: .oneEighty)
        let second = PDFItem(url: TestFixtures.sample2PDF, pageRotations: [1: .twoSeventy])
        let missing = URL(fileURLWithPath: "/tmp/missing.pdf")

        let rotations = PDFRotationMapper.rotations(
            urls: [TestFixtures.sample2PDF, missing, TestFixtures.samplePDF],
            from: [first, duplicate, second]
        )

        #expect(rotations == [second.rotation, .none, first.rotation])
    }
}

@Suite("Per-page rotation on export")
struct PerPageExportTests {
    private let service = PDFService()

    @Test("Merge composes saved, file and page rotation for every page")
    func merge() throws {
        let url = try makePDF(savedRotations: [0: 90, 1: 180])
        defer { try? FileManager.default.removeItem(at: url) }
        let count = try pageCount(url)
        let rotation = PDFRotation(file: .ninety, pages: [0: .twoSeventy, 1: .ninety])

        let merged = try #require(service.mergePDFs(urls: [url], rotations: [rotation]).document)

        #expect(merged.pageCount == count)
        #expect(merged.page(at: 0)?.rotation == 90)  // 90 + 90 + 270 = 450
        #expect(merged.page(at: 1)?.rotation == 0)   // 180 + 90 + 90
        for index in 2 ..< count {
            #expect(merged.page(at: index)?.rotation == 90)
        }
    }

    @Test("Split composes saved, file and page rotation for every page")
    func split() throws {
        let url = try makePDF(savedRotations: [0: 270])
        defer { try? FileManager.default.removeItem(at: url) }
        let count = try pageCount(url)
        let rotation = PDFRotation(file: .oneEighty, pages: [0: .oneEighty, 1: .ninety])

        let pages = service.splitPDF(urls: [url], rotations: [rotation]).pages

        #expect(pages.count == count)
        #expect(pages[0].document.page(at: 0)?.rotation == 270)   // 270 + 180 + 180
        #expect(pages[1].document.page(at: 0)?.rotation == 270)   // 0 + 180 + 90
        #expect(pages[1].fileName == SplitPage.fileName(sourceURL: url, pageNumber: 2))
    }

    @Test("Rotations match URLs by position, so the same file twice can differ")
    func positional() throws {
        let url = TestFixtures.sample2PDF
        let count = try pageCount(url)

        let merged = try #require(service.mergePDFs(
            urls: [url, url],
            rotations: [PDFRotation(pages: [0: .ninety]), PDFRotation(file: .oneEighty)]
        ).document)

        #expect(merged.pageCount == count * 2)
        #expect(merged.page(at: 0)?.rotation == 90)
        #expect(merged.page(at: count)?.rotation == 180)
    }

    @Test("Page rotations past the last page and missing entries are ignored")
    func outOfRange() throws {
        let url = TestFixtures.sample2PDF
        let count = try pageCount(url)

        let merged = try #require(service.mergePDFs(urls: [url, url], rotations: [PDFRotation(pages: [99: .ninety])]).document)

        #expect(merged.pageCount == count * 2)
        for index in 0 ..< merged.pageCount {
            #expect(merged.page(at: index)?.rotation == 0)
        }
    }

    @Test("The source file is never changed")
    func sourceUntouched() throws {
        let url = try makePDF(savedRotations: [0: 90])
        defer { try? FileManager.default.removeItem(at: url) }

        _ = service.splitPDF(urls: [url], rotations: [PDFRotation(file: .ninety, pages: [0: .ninety])])

        #expect(PDFDocument(url: url)?.page(at: 0)?.rotation == 90)
    }
}

@Suite("Page selection")
struct PageSelectionTests {
    @Test func clickSelectsOnlyThatPage() {
        var selection = PageSelection()
        selection.click(2)
        selection.click(4)
        #expect(selection.indexes == [4])
        #expect(selection.anchor == 4)
        #expect(selection.focus == 4)
    }

    @Test func commandClickToggles() {
        var selection = PageSelection()
        selection.click(1)
        selection.commandClick(3)
        #expect(selection.sorted == [1, 3])
        selection.commandClick(1)
        #expect(selection.sorted == [3])
    }

    @Test func shiftClickSelectsRangeFromAnchorInEitherDirection() {
        var selection = PageSelection()
        selection.click(3)
        selection.shiftClick(6)
        #expect(selection.sorted == [3, 4, 5, 6])
        selection.shiftClick(1)
        #expect(selection.sorted == [1, 2, 3])
        #expect(selection.anchor == 3)
        #expect(selection.focus == 1)
    }

    @Test func shiftClickKeepsPagesPickedBeforeTheAnchor() {
        var selection = PageSelection()
        selection.click(0)
        selection.commandClick(5)
        selection.shiftClick(7)
        #expect(selection.sorted == [0, 5, 6, 7])
        selection.shiftClick(4)
        #expect(selection.sorted == [0, 4, 5])
    }

    @Test func shiftClickWithoutAnchorActsLikeClick() {
        var selection = PageSelection()
        selection.shiftClick(2)
        #expect(selection.indexes == [2])
        #expect(selection.anchor == 2)
    }

    @Test func selectAllAndClear() {
        var selection = PageSelection()
        selection.selectAll(count: 4)
        #expect(selection.sorted == [0, 1, 2, 3])
        selection.clear()
        #expect(selection.isEmpty)
        #expect(selection.anchor == nil)
        selection.selectAll(count: 0)
        #expect(selection.isEmpty)
    }

    @Test func arrowStepsClampAndExtend() {
        var selection = PageSelection()
        selection.step(by: 1, count: 5, extending: false)
        #expect(selection.indexes == [0])
        selection.step(by: 3, count: 5, extending: false)
        #expect(selection.indexes == [3])
        selection.step(by: 3, count: 5, extending: false)
        #expect(selection.indexes == [4])
        selection.step(by: -2, count: 5, extending: true)
        #expect(selection.sorted == [2, 3, 4])
        #expect(selection.anchor == 4)
        selection.step(by: -10, count: 5, extending: false)
        #expect(selection.indexes == [0])
    }

    @Test func stepBackFromNothingStartsAtLastPage() {
        var selection = PageSelection()
        selection.step(by: -1, count: 5, extending: false)
        #expect(selection.indexes == [4])
        var empty = PageSelection()
        empty.step(by: 1, count: 0, extending: false)
        #expect(empty.isEmpty)
    }
}

@Suite("Page thumbnails")
struct PageThumbnailerTests {
    @Test func countsPagesAndDownsamples() async throws {
        let expected = try pageCount(TestFixtures.samplePDF)
        let thumbnailer = PDFPageThumbnailer(url: TestFixtures.samplePDF)

        #expect(await thumbnailer.pageCount() == expected)
        let image = try #require(await thumbnailer.thumbnail(at: 0, maxPixelSize: 64))
        #expect(max(image.width, image.height) == 64)
        #expect(await thumbnailer.thumbnail(at: expected, maxPixelSize: 64) == nil)
    }

    @Test func savedRotationTurnsTheThumbnail() async throws {
        let url = try makePDF(savedRotations: [0: 90])
        defer { try? FileManager.default.removeItem(at: url) }
        let page = try #require(PDFDocument(url: url)?.page(at: 0))
        let bounds = page.bounds(for: .cropBox)

        let image = try #require(await PDFPageThumbnailer(url: url).thumbnail(at: 0, maxPixelSize: 100))

        // Rotated a quarter turn, so width and height swap compared with the page box.
        #expect((image.width > image.height) == (bounds.height > bounds.width))
    }

    @Test func unreadableFileHasNoPages() async {
        let thumbnailer = PDFPageThumbnailer(url: URL(fileURLWithPath: "/tmp/beaver-missing-\(UUID().uuidString).pdf"))
        #expect(await thumbnailer.pageCount() == 0)
        #expect(await thumbnailer.thumbnail(at: 0, maxPixelSize: 64) == nil)
    }
}

@MainActor
@Suite("Page view in the reactor")
struct ReactorPageRotationTests {
    private let destination = URL(fileURLWithPath: "/tmp/beaver-page-rotation.pdf")

    private func makeReactor(export: MockExportService = MockExportService()) -> BeaverReactor {
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let reactor = BeaverReactor(saveLocationProvider: panels, imageService: MockImageService(), exportService: export)
        reactor.action(.setPDFs([PDFItem(url: TestFixtures.samplePDF), PDFItem(url: TestFixtures.sample2PDF)]))
        return reactor
    }

    @Test func rotatePagesChangesOnlyThatPDF() {
        let reactor = makeReactor()
        let first = reactor.state.pdfs[0]

        reactor.action(.rotatePages(id: first.id, pages: [0, 2], direction: .right))

        #expect(reactor.state.pdfs[0].pageRotations == [0: .ninety, 2: .ninety])
        #expect(reactor.state.pdfs[0].rotationAngle == .zero)
        #expect(!reactor.state.pdfs[1].hasPageRotations)
        #expect(reactor.state.hasDiscardableRotations)
        #expect(reactor.state.history.undoLabel == .rotatePages)
    }

    @Test func rotateAllPagesTurnsTheFile() {
        let reactor = makeReactor()
        let first = reactor.state.pdfs[0]
        reactor.action(.rotatePages(id: first.id, pages: [1], direction: .right))

        reactor.action(.rotateAllPages(id: first.id, direction: .left))

        #expect(reactor.state.pdfs[0].rotationAngle == .twoSeventy)
        #expect(reactor.state.pdfs[0].pageRotations == [1: .ninety])
        #expect(reactor.state.pdfs[0].rotation.userRotation(forPage: 1) == .zero)
        #expect(reactor.state.history.undoLabel == .rotateAllPages)
    }

    @Test func undoAndRedoRestorePageRotations() {
        let reactor = makeReactor()
        let id = reactor.state.pdfs[0].id
        reactor.action(.rotatePages(id: id, pages: [0], direction: .right))
        reactor.action(.rotate(id: id, direction: .right))
        reactor.action(.rotatePages(id: id, pages: [0, 1], direction: .right))

        reactor.action(.undo)
        #expect(reactor.state.pdfs[0].rotation == PDFRotation(file: .ninety, pages: [0: .ninety]))
        reactor.action(.undo)
        #expect(reactor.state.pdfs[0].rotation == PDFRotation(pages: [0: .ninety]))
        reactor.action(.undo)
        #expect(reactor.state.pdfs[0].rotation == .none)
        #expect(!reactor.state.canUndo)

        reactor.action(.redo)
        reactor.action(.redo)
        reactor.action(.redo)
        #expect(reactor.state.pdfs[0].rotation == PDFRotation(file: .ninety, pages: [0: .oneEighty, 1: .ninety]))
        #expect(!reactor.state.canRedo)
    }

    @Test func rotatingNoPagesRecordsNothing() {
        let reactor = makeReactor()
        let id = reactor.state.pdfs[0].id

        reactor.action(.rotatePages(id: id, pages: [], direction: .right))
        reactor.action(.rotatePages(id: UUID(), pages: [0], direction: .right))

        #expect(!reactor.state.canUndo)
    }

    @Test func pageRotationsAreIgnoredDuringActivity() async {
        let export = MockExportService(isGated: true)
        let reactor = makeReactor(export: export)
        let id = reactor.state.pdfs[0].id

        let running = Task { await reactor.exportOneFile() }
        while reactor.state.activity == nil {
            await Task.yield()
        }
        reactor.action(.rotatePages(id: id, pages: [0], direction: .right))
        reactor.action(.rotateAllPages(id: id, direction: .right))
        reactor.action(.showPages(id: id))
        export.release()
        await running.value

        #expect(reactor.state.pdfs[0].rotation == .none)
        #expect(!reactor.state.canUndo)
        #expect(reactor.state.pagesPDFID == nil)
    }

    @Test func reorderKeepsPageRotationsAndExportFollowsTheNewOrder() async {
        let export = MockExportService()
        let reactor = makeReactor(export: export)
        let first = reactor.state.pdfs[0]
        let second = reactor.state.pdfs[1]
        reactor.action(.rotatePages(id: first.id, pages: [1], direction: .left))
        reactor.action(.rotatePages(id: second.id, pages: [0], direction: .right))

        reactor.action(.move(id: second.id, to: 0))

        #expect(reactor.state.pdfs.map(\.id) == [second.id, first.id])
        #expect(reactor.state.pdfs[0].pageRotations == [0: .ninety])
        #expect(reactor.state.pdfs[1].pageRotations == [1: .twoSeventy])

        await reactor.exportOneFile()
        #expect(export.calls == [.merge(
            urls: [TestFixtures.sample2PDF, TestFixtures.samplePDF],
            rotations: [PDFRotation(pages: [0: .ninety]), PDFRotation(pages: [1: .twoSeventy])],
            destination: destination
        )])

        reactor.action(.undo)
        #expect(reactor.state.pdfs.map(\.id) == [first.id, second.id])
        #expect(reactor.state.pdfs[0].pageRotations == [1: .twoSeventy])
    }

    @Test func splitSendsPageRotations() async {
        let export = MockExportService()
        let reactor = makeReactor(export: export)
        let id = reactor.state.pdfs[0].id
        reactor.action(.rotate(id: id, direction: .right))
        reactor.action(.rotatePages(id: id, pages: [0], direction: .right))
        let directory = URL(fileURLWithPath: "/tmp", isDirectory: true)

        await reactor.action(.perform(.split))
        await reactor.action(.didImportFiles([directory]))

        #expect(export.calls == [.split(
            urls: [TestFixtures.samplePDF, TestFixtures.sample2PDF],
            rotations: [PDFRotation(file: .ninety, pages: [0: .ninety]), PDFRotation()],
            directory: directory
        )])
    }

    @Test func pageViewOpensAndCloses() {
        let reactor = makeReactor()
        let id = reactor.state.pdfs[1].id
        #expect(reactor.state.canRotateAll)

        reactor.action(.showPages(id: id))
        #expect(reactor.state.isPagesPresented)
        #expect(reactor.state.pagesPDF?.id == id)
        #expect(!reactor.state.canRotateAll)

        reactor.action(.didChangePagesPresented(true))
        #expect(reactor.state.pagesPDFID == id)
        reactor.action(.didChangePagesPresented(false))
        #expect(!reactor.state.isPagesPresented)
        #expect(reactor.state.canRotateAll)

        reactor.action(.showPages(id: UUID()))
        #expect(!reactor.state.isPagesPresented)
    }

    @Test func deletingOrClearingClosesThePageView() async {
        let reactor = makeReactor()
        let id = reactor.state.pdfs[0].id
        reactor.action(.showPages(id: id))

        reactor.action(.remove([id]))
        #expect(reactor.state.pagesPDFID == nil)

        reactor.action(.showPages(id: reactor.state.pdfs[0].id))
        await reactor.action(.requestRemoveAll)
        await reactor.action(.confirmRemoveAll)
        #expect(reactor.state.pagesPDFID == nil)
    }

    @Test func pageEditTitles() {
        #expect(BeaverReactor.Edit.rotatePages.title == "Rotate Pages")
        #expect(BeaverReactor.Edit.rotateAllPages.title == "Rotate All Pages")
        #expect(DesignSystem.Pages.pageAccessibilityLabel(2, rotation: .ninety) == "Page 3, rotated 90 degrees")
        #expect(DesignSystem.Pages.pageAccessibilityLabel(0, rotation: .zero) == "Page 1")
    }

    @Test func mergeWritesComposedPageRotations() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BeaverPageRotation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try makePDF(savedRotations: [1: 90])
        defer { try? FileManager.default.removeItem(at: source) }
        let output = directory.appendingPathComponent("merged.pdf")
        let panels = MockSaveLocationProvider()
        panels.saveURL = output
        let reactor = BeaverReactor(saveLocationProvider: panels, imageService: MockImageService(), exportService: ExportService())
        reactor.action(.setPDFs([PDFItem(url: source), PDFItem(url: TestFixtures.samplePDF)]))
        let id = reactor.state.pdfs[0].id
        reactor.action(.rotate(id: id, direction: .right))
        reactor.action(.rotatePages(id: id, pages: [1], direction: .right))

        await reactor.exportOneFile()

        let merged = try #require(PDFDocument(url: output))
        #expect(merged.page(at: 0)?.rotation == 90)    // 0 + 90 + 0
        #expect(merged.page(at: 1)?.rotation == 270)   // 90 + 90 + 90
    }
}
