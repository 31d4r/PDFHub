import BeaverCore
import Foundation
import Testing
@testable import Beaver

/// Exports never add their output to the list; the banner offers Add to Beaver for a new PDF.
@MainActor
struct AddExportTests {
    private let output = URL(fileURLWithPath: "/tmp/beaver-tests/Combined.pdf")

    private func reactor(alertOutput: URL?) async -> BeaverReactor {
        let panels = MockSaveLocationProvider()
        panels.saveURL = output
        let export = MockExportService(result: ExportAlert(message: "Saved", isSuccess: true, output: alertOutput))
        let reactor = BeaverReactor(saveLocationProvider: panels, imageService: MockImageService(), exportService: export)
        await reactor.action(.addFiles([TestFixtures.samplePDF, TestFixtures.sample2PDF]))
        return reactor
    }

    @Test func exportDoesNotAddItsOutput() async {
        let reactor = await reactor(alertOutput: output)
        await reactor.action(.perform(.merge))

        #expect(reactor.state.items.map(\.url) == [TestFixtures.samplePDF, TestFixtures.sample2PDF])
        #expect(reactor.state.exportToAdd == output)
    }

    @Test func addToBeaverAddsTheNewPDFOnce() async {
        let reactor = await reactor(alertOutput: output)
        await reactor.action(.perform(.merge))

        await reactor.action(.addExportToWorkspace)
        #expect(reactor.state.items.map(\.url) == [TestFixtures.samplePDF, TestFixtures.sample2PDF, output])
        #expect(reactor.state.exportToAdd == nil)
        #expect(reactor.state.history.undoLabel == .add)

        await reactor.action(.addExportToWorkspace)
        #expect(reactor.state.items.count == 3)
    }

    @Test func foldersAndListedFilesAreNotOffered() async {
        let folder = URL(fileURLWithPath: "/tmp/beaver-tests/pages", isDirectory: true)
        let split = await reactor(alertOutput: folder)
        await split.action(.perform(.merge))
        #expect(split.state.exportToAdd == nil)

        let overwrite = await reactor(alertOutput: TestFixtures.samplePDF)
        await overwrite.action(.perform(.merge))
        #expect(overwrite.state.exportToAdd == nil)
    }

    @Test func nothingIsOfferedWithoutASuccessfulExport() async {
        let reactor = await reactor(alertOutput: output)
        #expect(reactor.state.exportToAdd == nil)
        await reactor.action(.addExportToWorkspace)
        #expect(reactor.state.items.count == 2)

        await reactor.action(.perform(.merge))
        reactor.action(.didDismissAlert)
        #expect(reactor.state.exportToAdd == nil)
    }

    @Test func addToBeaverIsLocalized() {
        #expect(DesignSystem.Export.addToWorkspace == "Add to Beaver")
        for key in ["export.addToWorkspace", "export.addToWorkspace.help"] {
            #expect(Bundle.main.localizedString(forKey: key, value: "\u{1}missing", table: "Localizable") != "\u{1}missing", "\(key)")
        }
    }
}
