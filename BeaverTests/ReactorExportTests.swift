import BeaverCore
import Foundation
import Testing
@testable import Beaver

@MainActor
struct ReactorExportTests {
    private let destination = URL(fileURLWithPath: "/tmp/beaver-tests/merged.pdf")
    private let directory = URL(fileURLWithPath: "/tmp/beaver-tests/split", isDirectory: true)

    private func makeReactor(
        panels: MockFilePanelService = MockFilePanelService(),
        export: MockExportService = MockExportService(),
        images: MockImageService = MockImageService()
    ) -> BeaverReactor {
        BeaverReactor(filePanelService: panels, imageService: images, exportService: export)
    }

    @Test func mergePassesURLsRotationsAndDestination() async {
        let panels = MockFilePanelService()
        panels.saveURL = destination
        let export = MockExportService(result: ExportAlert(message: "merged", isSuccess: true))
        let reactor = makeReactor(panels: panels, export: export)
        let urls = [TestFixtures.samplePDF, TestFixtures.sample2PDF]
        await reactor.action(.addPDFs(urls))

        await reactor.action(.mergePDF(urls))

        #expect(export.calls == [.merge(
            urls: urls,
            rotationAngles: [TestFixtures.samplePDF: 0, TestFixtures.sample2PDF: 0],
            destination: destination
        )])
        #expect(reactor.state.exportAlert == ExportAlert(message: "merged", isSuccess: true))
        #expect(reactor.state.activity == nil)
    }

    @Test func mergeDoesNothingWhenSavePanelIsCancelled() async {
        let export = MockExportService()
        let reactor = makeReactor(export: export)
        await reactor.action(.addPDFs([TestFixtures.samplePDF]))

        await reactor.action(.mergePDF([TestFixtures.samplePDF]))

        #expect(export.calls.isEmpty)
        #expect(reactor.state.exportAlert == nil)
    }

    @Test func mergeIgnoresEmptyList() async {
        let panels = MockFilePanelService()
        panels.saveURL = destination
        let export = MockExportService()
        let reactor = makeReactor(panels: panels, export: export)

        await reactor.action(.mergePDF([]))

        #expect(export.calls.isEmpty)
    }

    @Test func splitUsesChosenDirectory() async {
        let panels = MockFilePanelService()
        panels.directoryURL = directory
        let failure = ExportAlert(message: "failed", isSuccess: false)
        let export = MockExportService(result: failure)
        let reactor = makeReactor(panels: panels, export: export)
        await reactor.action(.addPDFs([TestFixtures.samplePDF]))

        await reactor.action(.splitPDF([TestFixtures.samplePDF]))

        #expect(export.calls == [.split(
            urls: [TestFixtures.samplePDF],
            rotationAngles: [TestFixtures.samplePDF: 0],
            directory: directory
        )])
        #expect(reactor.state.exportAlert == failure)
    }

    @Test func convertSendsSelectedImagesInOrder() async {
        let panels = MockFilePanelService()
        panels.saveURL = destination
        let images = MockImageService()
        let second = URL(fileURLWithPath: "/tmp/second.png")
        images.thumbnailsByURL[TestFixtures.samplePNG] = TestImages.solid(width: 4, height: 4)
        images.thumbnailsByURL[second] = TestImages.solid(width: 4, height: 4)
        let export = MockExportService()
        let reactor = makeReactor(panels: panels, export: export, images: images)
        await reactor.action(.addImages([TestFixtures.samplePNG, second]))

        await reactor.action(.convertImagesToPDF)

        #expect(export.calls == [.convert(urls: [TestFixtures.samplePNG, second], destination: destination)])
    }

    @Test func convertWithoutImagesShowsError() async {
        let export = MockExportService()
        let reactor = makeReactor(export: export)

        await reactor.action(.convertImagesToPDF)

        #expect(export.calls.isEmpty)
        #expect(reactor.state.exportAlert == ExportAlert(message: DesignSystem.Alerts.noImagesSelected, isSuccess: false))
    }

    @Test func secondExportIsIgnoredWhileOneIsRunning() async {
        let panels = MockFilePanelService()
        panels.saveURL = destination
        let export = MockExportService(isGated: true)
        let reactor = makeReactor(panels: panels, export: export)
        await reactor.action(.addPDFs([TestFixtures.samplePDF]))

        let running = Task { await reactor.action(.mergePDF([TestFixtures.samplePDF])) }
        while reactor.state.activity == nil {
            await Task.yield()
        }
        #expect(reactor.state.activity == .merging)

        await reactor.action(.mergePDF([TestFixtures.samplePDF]))
        await reactor.action(.addPDFs([TestFixtures.sample2PDF]))
        #expect(export.calls.count == 1)
        #expect(reactor.state.selectedPDFs.count == 1)

        export.release()
        await running.value

        #expect(reactor.state.activity == nil)
        #expect(reactor.state.exportAlert?.isSuccess == true)
    }
}
