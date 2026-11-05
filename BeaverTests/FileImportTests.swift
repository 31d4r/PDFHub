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

    @Test func chooseFilesPresentsImporterAndAddsChosenFiles() async {
        let reactor = makeReactor()

        await reactor.action(.chooseFiles)
        #expect(reactor.state.fileImport == .files)
        #expect(reactor.state.isFileImporterPresented)

        await reactor.action(.didImportFiles([TestFixtures.samplePDF, TestFixtures.sample2PDF]))

        #expect(reactor.state.pdfs.map(\.url) == [TestFixtures.samplePDF, TestFixtures.sample2PDF])
        #expect(reactor.state.fileImport == nil)
        #expect(!reactor.state.isFileImporterPresented)
    }

    @Test func chooseFilesAcceptsImagesAndPDFsTogether() async {
        let images = MockImageService()
        images.thumbnailsByURL[TestFixtures.samplePNG] = TestImages.solid(width: 4, height: 4)
        let reactor = makeReactor(images: images)

        await reactor.action(.chooseFiles)
        #expect(reactor.state.fileImport == .files)

        await reactor.action(.didImportFiles([TestFixtures.samplePNG, TestFixtures.samplePDF]))

        #expect(reactor.state.items.map(\.url) == [TestFixtures.samplePNG, TestFixtures.samplePDF])
    }

    @Test func completionStillAppliesAfterImporterIsDismissed() async {
        let reactor = makeReactor()
        await reactor.action(.chooseFiles)

        reactor.action(.didChangeFileImporterPresented(false))
        await reactor.action(.didImportFiles([TestFixtures.samplePDF]))

        #expect(reactor.state.pdfs.count == 1)
    }

    @Test func completionWithoutRequestIsIgnored() async {
        let export = MockExportService()
        let reactor = makeReactor(export: export)

        await reactor.action(.didImportFiles([TestFixtures.samplePDF]))

        #expect(reactor.state.pdfs.isEmpty)
        #expect(export.calls.isEmpty)
    }

    @Test func splitAsksForFolderAndDoesNothingUntilChosen() async {
        let export = MockExportService()
        let reactor = makeReactor(export: export)
        await reactor.action(.addFiles([TestFixtures.samplePDF]))

        await reactor.action(.splitIntoPages)

        #expect(reactor.state.fileImport == .splitDestination([.pdf(TestFixtures.samplePDF, .none)]))
        #expect(reactor.state.isFileImporterPresented)
        #expect(export.calls.isEmpty)
    }

    @Test func splitIgnoresEmptyList() async {
        let reactor = makeReactor()

        await reactor.action(.splitIntoPages)

        #expect(reactor.state.fileImport == nil)
        #expect(!reactor.state.isFileImporterPresented)
    }

    @Test func importerFailureShowsAlert() async {
        let reactor = makeReactor()
        await reactor.action(.chooseFiles)

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
        await reactor.action(.addFiles([TestFixtures.samplePDF]))
        let running = Task { await reactor.action(.createPDF) }
        while reactor.state.activity == nil {
            await Task.yield()
        }

        await reactor.action(.chooseFiles)
        #expect(reactor.state.fileImport == nil)

        export.release()
        await running.value
    }

    @Test func requestsDescribeTheImporter() {
        #expect(FileImportRequest.files.allowedContentTypes == [.pdf] + SupportedImageType.allUTTypes)
        #expect(FileImportRequest.splitDestination([]).allowedContentTypes == [.folder])
        #expect(FileImportRequest.files.allowsMultipleSelection)
        #expect(!FileImportRequest.splitDestination([]).allowsMultipleSelection)
        #expect(FileImportRequest.files.confirmationLabel == DesignSystem.FileNames.addFilesPrompt)
        #expect(FileImportRequest.splitDestination([]).confirmationLabel == DesignSystem.FileNames.saveSplitPDFsPrompt)
    }
}
