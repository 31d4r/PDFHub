import BeaverCore
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Beaver

@MainActor
struct ReactorPageExportTests {
    private let destination = URL(fileURLWithPath: "/tmp/beaver-tests/page.png")
    private let directory = URL(fileURLWithPath: "/tmp/beaver-tests/images", isDirectory: true)

    private func makeReactor(
        panels: MockSaveLocationProvider,
        export: MockExportService
    ) -> BeaverReactor {
        BeaverReactor(saveLocationProvider: panels, imageService: MockImageService(), exportService: export)
    }

    private func pdfID(_ reactor: BeaverReactor) throws -> UUID {
        try #require(reactor.state.pdfs.first?.id)
    }

    // MARK: - Whole PDFs from the workspace

    @Test func exportAsPNGSavesEveryPageIntoAFolder() async {
        let panels = MockSaveLocationProvider()
        panels.folderURL = directory
        let export = MockExportService()
        let reactor = makeReactor(panels: panels, export: export)
        await reactor.action(.addFiles([TestFixtures.samplePDF]))

        await reactor.action(.perform(.exportPNG))

        #expect(panels.requestedFolderNames == ["sample_images"])
        #expect(export.calls == [.exportPageImages(
            sources: [PageExportSource(url: TestFixtures.samplePDF)],
            format: .png,
            directory: directory
        )])
        #expect(reactor.state.activity == nil)
        #expect(reactor.state.exportAlert == ExportAlert(message: "done", isSuccess: true))
    }

    @Test func exportAsJPEGUsesJPEGAndKeepsRotations() async {
        let panels = MockSaveLocationProvider()
        panels.folderURL = directory
        let export = MockExportService()
        let reactor = makeReactor(panels: panels, export: export)
        await reactor.action(.addFiles([TestFixtures.samplePDF]))
        let id = reactor.state.pdfs[0].id
        reactor.action(.rotate(id: id, direction: .right))

        await reactor.action(.perform(.exportJPEG))

        #expect(export.calls == [.exportPageImages(
            sources: [PageExportSource(url: TestFixtures.samplePDF, rotation: PDFRotation(file: .ninety))],
            format: .jpeg,
            directory: directory
        )])
    }

    @Test func cancellingTheFolderPanelExportsNothing() async {
        let panels = MockSaveLocationProvider()
        let export = MockExportService()
        let reactor = makeReactor(panels: panels, export: export)
        await reactor.action(.addFiles([TestFixtures.samplePDF]))

        await reactor.action(.perform(.exportPNG))

        #expect(panels.requestedFolderNames.count == 1)
        #expect(export.calls.isEmpty)
        #expect(reactor.state.exportAlert == nil)
    }

    @Test func imageExportsNeedAPDF() {
        let reactor = makeReactor(panels: MockSaveLocationProvider(), export: MockExportService())
        let images = [WorkspaceItem.image(ImageItem(url: TestFixtures.samplePNG, thumbnail: TestImages.solid(width: 4, height: 4)))]

        #expect(DocumentAction.exportPNG.availability(for: images, selection: false, isBusy: false)
            == .unavailable(.needsPDFForImages(selection: false)))
        #expect(DocumentAction.exportJPEG.availability(for: images, selection: true, isBusy: false)
            == .unavailable(.needsPDFForImages(selection: true)))
        #expect(!reactor.state.availability(of: .exportPNG).isAvailable)
    }

    // MARK: - Pages from the page view

    @Test func onePageAsAnImageAsksForOneFile() async throws {
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let export = MockExportService()
        let reactor = makeReactor(panels: panels, export: export)
        await reactor.action(.addFiles([TestFixtures.samplePDF]))

        await reactor.action(.exportPages(id: try pdfID(reactor), pages: [1], format: .png))

        #expect(panels.requestedNames == ["sample_page-2.png"])
        #expect(panels.requestedTypes == [.png])
        #expect(panels.requestedFolderNames.isEmpty)
        #expect(export.calls == [.exportPages(
            source: PageExportSource(url: TestFixtures.samplePDF, pages: [1]),
            format: .png,
            destination: destination
        )])
    }

    @Test func selectedPagesAsAPDFAreNamedForThePages() async throws {
        let panels = MockSaveLocationProvider()
        panels.saveURL = URL(fileURLWithPath: "/tmp/beaver-tests/pages.pdf")
        let export = MockExportService()
        let reactor = makeReactor(panels: panels, export: export)
        await reactor.action(.addFiles([TestFixtures.samplePDF]))
        let id = try pdfID(reactor)

        await reactor.action(.exportPages(id: id, pages: [1], format: .pdf))
        await reactor.action(.exportPages(id: id, pages: [0, 1], format: .pdf))
        await reactor.action(.exportPages(id: id, pages: nil, format: .pdf))

        #expect(panels.requestedNames == ["sample_page-2.pdf", "sample_pages-1-2.pdf", "sample_pages-1-2.pdf"])
        #expect(panels.requestedTypes == [.pdf, .pdf, .pdf])
        #expect(export.calls.count == 3)
    }

    @Test func severalSelectedPagesAsImagesGoIntoAFolder() async throws {
        let panels = MockSaveLocationProvider()
        panels.folderURL = directory
        let export = MockExportService()
        let reactor = makeReactor(panels: panels, export: export)
        await reactor.action(.addFiles([TestFixtures.samplePDF]))

        await reactor.action(.exportPages(id: try pdfID(reactor), pages: [1, 0], format: .jpeg))

        #expect(panels.requestedNames.isEmpty)
        #expect(export.calls == [.exportPageImages(
            sources: [PageExportSource(url: TestFixtures.samplePDF, pages: [1, 0])],
            format: .jpeg,
            directory: directory
        )])
    }

    @Test func singlePagePDFAsImageIsOneFile() async throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = PageExportFixtures.makePDF(pages: 1, named: "receipt.pdf", in: folder)
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let export = MockExportService()
        let reactor = makeReactor(panels: panels, export: export)
        await reactor.action(.addFiles([url]))

        await reactor.action(.perform(.exportPNG))

        #expect(panels.requestedNames == ["receipt_page-1.png"])
        #expect(export.calls == [.exportPages(source: PageExportSource(url: url), format: .png, destination: destination)])
    }

    @Test func thePageViewClosesBeforeTheExportStarts() async throws {
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let export = MockExportService()
        let reactor = makeReactor(panels: panels, export: export)
        await reactor.action(.addFiles([TestFixtures.samplePDF]))
        let id = try pdfID(reactor)
        reactor.action(.showPages(id: id))

        await reactor.action(.exportPages(id: id, pages: [0], format: .png))

        #expect(!reactor.state.isPagesPresented)
        #expect(reactor.state.pendingPageExport != nil)
        #expect(export.calls.isEmpty)
        #expect(panels.requestedNames.isEmpty)

        await reactor.action(.didDismissPages)

        #expect(reactor.state.pendingPageExport == nil)
        #expect(panels.requestedNames == ["sample_page-1.png"])
        #expect(export.calls.count == 1)
    }

    @Test func closingThePageViewWithoutExportingDoesNothing() async throws {
        let export = MockExportService()
        let reactor = makeReactor(panels: MockSaveLocationProvider(), export: export)
        await reactor.action(.addFiles([TestFixtures.samplePDF]))
        reactor.action(.showPages(id: try pdfID(reactor)))
        reactor.action(.didChangePagesPresented(false))

        await reactor.action(.didDismissPages)

        #expect(export.calls.isEmpty)
    }

    @Test func lockedPDFIsReportedBeforeAskingWhereToSave() async throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let locked = try PageExportFixtures.makeLockedPDF(in: folder)
        let panels = MockSaveLocationProvider()
        panels.folderURL = directory
        let export = MockExportService()
        let reactor = makeReactor(panels: panels, export: export)
        await reactor.action(.addFiles([locked]))

        await reactor.action(.perform(.exportPNG))

        #expect(panels.requestedFolderNames.isEmpty)
        #expect(export.calls.isEmpty)
        #expect(reactor.state.exportAlert == ExportAlert(
            message: DesignSystem.Alerts.pageExportFailed(.locked(locked)),
            isSuccess: false
        ))
    }

    @Test func noPagesChosenIsAnError() async throws {
        let export = MockExportService()
        let reactor = makeReactor(panels: MockSaveLocationProvider(), export: export)
        await reactor.action(.addFiles([TestFixtures.samplePDF]))

        await reactor.action(.exportPages(id: try pdfID(reactor), pages: [], format: .pdf))

        #expect(export.calls.isEmpty)
        #expect(reactor.state.exportAlert?.isSuccess == false)
    }

    @Test func ignoredWhileAnotherExportRuns() async throws {
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let export = MockExportService(isGated: true)
        let reactor = makeReactor(panels: panels, export: export)
        await reactor.action(.addFiles([TestFixtures.samplePDF]))
        let id = try pdfID(reactor)

        let first = Task { await reactor.action(.exportPages(id: id, pages: [0], format: .png)) }
        while reactor.state.activity == nil { await Task.yield() }
        #expect(reactor.state.activity == .exportingImages)

        await reactor.action(.exportPages(id: id, pages: [1], format: .png))
        export.release()
        await first.value

        #expect(export.calls.count == 1)
    }
}
