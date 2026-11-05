import BeaverCore
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Beaver

@MainActor
struct FileImportTests {
    private func makeReactor(
        export: MockExportService = MockExportService(),
        images: MockImageService = MockImageService()
    ) -> BeaverReactor {
        BeaverReactor(
            saveLocationProvider: MockSaveLocationProvider(),
            imageService: images,
            exportService: export
        )
    }

    @Test func selectPDFPresentsImporterAndAddsChosenFiles() async {
        let reactor = makeReactor()

        await reactor.action(.selectPDF)
        #expect(reactor.state.fileImport == .pdfs)
        #expect(reactor.state.isFileImporterPresented)

        await reactor.action(.didImportFiles([TestFixtures.samplePDF, TestFixtures.sample2PDF]))

        #expect(reactor.state.selectedPDFs.map(\.url) == [TestFixtures.samplePDF, TestFixtures.sample2PDF])
        #expect(reactor.state.screen == .pdfWorkflow)
        #expect(reactor.state.fileImport == nil)
        #expect(!reactor.state.isFileImporterPresented)
    }

    @Test func selectImagesAddsChosenImages() async {
        let images = MockImageService()
        images.thumbnailsByURL[TestFixtures.samplePNG] = TestImages.solid(width: 4, height: 4)
        let reactor = makeReactor(images: images)

        await reactor.action(.selectImages)
        #expect(reactor.state.fileImport == .images)

        await reactor.action(.didImportFiles([TestFixtures.samplePNG]))

        #expect(reactor.state.selectedImages.map(\.url) == [TestFixtures.samplePNG])
        #expect(reactor.state.screen == .imageWorkflow)
    }

    @Test func completionStillAppliesAfterImporterIsDismissed() async {
        let reactor = makeReactor()
        await reactor.action(.selectPDF)

        reactor.action(.didChangeFileImporterPresented(false))
        await reactor.action(.didImportFiles([TestFixtures.samplePDF]))

        #expect(reactor.state.selectedPDFs.count == 1)
    }

    @Test func completionWithoutRequestIsIgnored() async {
        let export = MockExportService()
        let reactor = makeReactor(export: export)

        await reactor.action(.didImportFiles([TestFixtures.samplePDF]))

        #expect(reactor.state.selectedPDFs.isEmpty)
        #expect(export.calls.isEmpty)
    }

    @Test func splitAsksForFolderAndDoesNothingUntilChosen() async {
        let export = MockExportService()
        let reactor = makeReactor(export: export)
        await reactor.action(.addPDFs([TestFixtures.samplePDF]))

        await reactor.action(.splitPDF([TestFixtures.samplePDF]))

        #expect(reactor.state.fileImport == .splitDestination([TestFixtures.samplePDF]))
        #expect(reactor.state.isFileImporterPresented)
        #expect(export.calls.isEmpty)
    }

    @Test func splitIgnoresEmptyList() async {
        let reactor = makeReactor()

        await reactor.action(.splitPDF([]))

        #expect(reactor.state.fileImport == nil)
        #expect(!reactor.state.isFileImporterPresented)
    }

    @Test func importerFailureShowsAlert() async {
        let reactor = makeReactor()
        await reactor.action(.selectPDF)

        await reactor.action(.didFailFileImport("Couldn't read"))

        #expect(reactor.state.exportAlert == ExportAlert(message: "Couldn't read", isSuccess: false))
        #expect(reactor.state.fileImport == nil)
    }

    @Test func importerIsNotShownWhileExporting() async {
        let panels = MockSaveLocationProvider()
        panels.saveURL = URL(fileURLWithPath: "/tmp/beaver-tests/merged.pdf")
        let export = MockExportService(isGated: true)
        let reactor = BeaverReactor(
            saveLocationProvider: panels,
            imageService: MockImageService(),
            exportService: export
        )
        await reactor.action(.addPDFs([TestFixtures.samplePDF]))
        let running = Task { await reactor.action(.mergePDF([TestFixtures.samplePDF])) }
        while reactor.state.activity == nil {
            await Task.yield()
        }

        await reactor.action(.selectPDF)
        #expect(reactor.state.fileImport == nil)

        export.release()
        await running.value
    }

    @Test func requestsDescribeTheImporter() {
        #expect(FileImportRequest.pdfs.allowedContentTypes == [.pdf])
        #expect(FileImportRequest.images.allowedContentTypes == SupportedImageType.allUTTypes)
        #expect(FileImportRequest.splitDestination([]).allowedContentTypes == [.folder])
        #expect(FileImportRequest.pdfs.allowsMultipleSelection)
        #expect(!FileImportRequest.splitDestination([]).allowsMultipleSelection)
        #expect(FileImportRequest.pdfs.confirmationLabel == nil)
        #expect(FileImportRequest.splitDestination([]).confirmationLabel == DesignSystem.FileNames.saveSplitPDFsPrompt)
    }
}
