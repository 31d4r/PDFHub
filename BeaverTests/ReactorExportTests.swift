import BeaverCore
import Foundation
import Testing
@testable import Beaver

@MainActor
struct ReactorExportTests {
    private let destination = URL(fileURLWithPath: "/tmp/beaver-tests/merged.pdf")
    private let directory = URL(fileURLWithPath: "/tmp/beaver-tests/split", isDirectory: true)

    private func makeReactor(
        panels: MockSaveLocationProvider = MockSaveLocationProvider(),
        export: MockExportService = MockExportService(),
        images: MockImageService = MockImageService()
    ) -> BeaverReactor {
        BeaverReactor(saveLocationProvider: panels, imageService: images, exportService: export)
    }

    private let secondPNG = URL(fileURLWithPath: "/tmp/second.png")

    private func makeImages() -> MockImageService {
        let images = MockImageService()
        images.thumbnailsByURL[TestFixtures.samplePNG] = TestImages.solid(width: 4, height: 4)
        images.thumbnailsByURL[secondPNG] = TestImages.solid(width: 4, height: 4)
        return images
    }

    @Test func createPDFMergesWhenEveryTargetIsAPDF() async {
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let export = MockExportService(result: ExportAlert(message: "merged", isSuccess: true))
        let reactor = makeReactor(panels: panels, export: export)
        let urls = [TestFixtures.samplePDF, TestFixtures.sample2PDF]
        await reactor.action(.addFiles(urls))

        await reactor.exportOneFile()

        #expect(export.calls == [.merge(
            urls: urls,
            rotations: [.none, .none],
            destination: destination
        )])
        #expect(reactor.state.exportAlert == ExportAlert(message: "merged", isSuccess: true))
        #expect(reactor.state.activity == nil)
    }

    @Test func createPDFDoesNothingWhenSavePanelIsCancelled() async {
        let export = MockExportService()
        let reactor = makeReactor(export: export)
        await reactor.action(.addFiles([TestFixtures.samplePDF]))

        await reactor.exportOneFile()

        #expect(export.calls.isEmpty)
        #expect(reactor.state.exportAlert == nil)
    }

    @Test func createPDFIgnoresEmptyList() async {
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let export = MockExportService()
        let reactor = makeReactor(panels: panels, export: export)

        await reactor.exportOneFile()

        #expect(export.calls.isEmpty)
    }

    @Test func splitUsesOnlyTheSelection() async {
        let export = MockExportService()
        let reactor = makeReactor(export: export)
        await reactor.action(.addFiles([TestFixtures.samplePDF, TestFixtures.sample2PDF]))
        reactor.action(.select(reactor.state.items[1].id, .none))

        await reactor.action(.perform(.split))
        await reactor.action(.didImportFiles([directory]))

        #expect(export.calls == [.split(urls: [TestFixtures.sample2PDF], rotations: [.none], directory: directory)])
    }

    @Test func splitUsesChosenDirectory() async {
        let failure = ExportAlert(message: "failed", isSuccess: false)
        let export = MockExportService(result: failure)
        let reactor = makeReactor(export: export)
        await reactor.action(.addFiles([TestFixtures.samplePDF]))

        await reactor.action(.perform(.split))
        await reactor.action(.didImportFiles([directory]))

        #expect(export.calls == [.split(
            urls: [TestFixtures.samplePDF],
            rotations: [.none],
            directory: directory
        )])
        #expect(reactor.state.exportAlert == failure)
    }

    @Test func splitPDFSkipsImages() async {
        let export = MockExportService()
        let reactor = makeReactor(export: export, images: makeImages())
        await reactor.action(.addFiles([TestFixtures.samplePNG, TestFixtures.samplePDF]))
        reactor.action(.rotate(id: reactor.state.items[0].id, direction: .right))

        await reactor.action(.perform(.split))
        await reactor.action(.didImportFiles([directory]))

        #expect(export.calls == [.split(urls: [TestFixtures.samplePDF], rotations: [.none], directory: directory)])
    }

    @Test func createPDFConvertsWhenEveryTargetIsAnImage() async {
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let export = MockExportService()
        let reactor = makeReactor(panels: panels, export: export, images: makeImages())
        await reactor.action(.addFiles([TestFixtures.samplePNG, secondPNG]))

        await reactor.exportOneFile()

        #expect(export.calls == [.convert(urls: [TestFixtures.samplePNG, secondPNG], rotations: [.zero, .zero], destination: destination)])
        #expect(panels.requestedNames == [DesignSystem.FileNames.convertedImagesPDF])
    }

    @Test func createPDFCombinesMixedFilesInListOrder() async {
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let export = MockExportService()
        let reactor = makeReactor(panels: panels, export: export, images: makeImages())
        await reactor.action(.addFiles([TestFixtures.samplePNG, TestFixtures.samplePDF]))

        await reactor.exportOneFile()

        #expect(export.calls == [.combine(
            sources: [.image(TestFixtures.samplePNG, .zero), .pdf(TestFixtures.samplePDF, .none)],
            destination: destination
        )])
        #expect(panels.requestedNames == [DesignSystem.FileNames.combinedPDF])
    }

    @Test func secondExportIsIgnoredWhileOneIsRunning() async {
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let export = MockExportService(isGated: true)
        let reactor = makeReactor(panels: panels, export: export)
        await reactor.action(.addFiles([TestFixtures.samplePDF, TestFixtures.sample2PDF]))

        let running = Task { await reactor.exportOneFile() }
        while export.calls.isEmpty {
            await Task.yield()
        }
        #expect(reactor.state.activity == .merging)
        #expect(!reactor.state.canEdit)

        await reactor.exportOneFile()
        await reactor.action(.addFiles([TestFixtures.samplePNG]))
        #expect(export.calls.count == 1)
        #expect(reactor.state.items.count == 2)

        export.release()
        await running.value

        #expect(reactor.state.activity == nil)
        #expect(reactor.state.exportAlert?.isSuccess == true)
    }
}
