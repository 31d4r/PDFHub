import BeaverCore
import Foundation
import Testing
@testable import Beaver

/// Cancel in the progress bar, and the saved location the success banner reveals.
@MainActor
struct ExportCancellationTests {
    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BeaverCancelTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func cancelStopsTheExportAndShowsNothing() async {
        let panels = MockSaveLocationProvider()
        panels.saveURL = URL(fileURLWithPath: "/tmp/beaver-tests/merged.pdf")
        let export = MockExportService(result: ExportAlert(message: "merged", isSuccess: true), isGated: true)
        let reactor = BeaverReactor(saveLocationProvider: panels, imageService: MockImageService(), exportService: export)
        await reactor.action(.addFiles([TestFixtures.samplePDF]))

        let running = Task { await reactor.action(.createPDF) }
        while reactor.state.activity == nil {
            await Task.yield()
        }
        reactor.action(.cancelExport)
        await running.value

        #expect(reactor.state.activity == nil)
        #expect(reactor.state.exportAlert == nil)
        #expect(reactor.state.canEdit)
    }

    @Test func cancelWithoutAnExportDoesNothing() async {
        let reactor = BeaverReactor(
            saveLocationProvider: MockSaveLocationProvider(),
            imageService: MockImageService(),
            exportService: MockExportService()
        )
        await reactor.action(.addFiles([TestFixtures.samplePDF]))

        reactor.action(.cancelExport)

        #expect(reactor.state.activity == nil)
        #expect(reactor.state.items.count == 1)
    }

    @Test func cancelledMergeWritesNoFile() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("merged.pdf")

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await ExportService().mergePDFs(urls: [TestFixtures.samplePDF], rotations: [], to: destination)
        }
        let alert = await task.value

        #expect(alert == .cancelled)
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func cancelledSplitWritesNoPages() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await ExportService().splitPDFs(urls: [TestFixtures.sample2PDF], rotations: [], into: directory)
        }
        let alert = await task.value

        #expect(alert == .cancelled)
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(files.isEmpty)
    }

    @Test func mergeReportsTheSavedFile() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("merged.pdf")

        let alert = await ExportService().mergePDFs(urls: [TestFixtures.samplePDF], rotations: [], to: destination)

        #expect(alert.isSuccess)
        #expect(alert.output == destination)
    }

    @Test func convertReportsTheSavedFile() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("images.pdf")

        let alert = await ExportService().convertImages(urls: [TestFixtures.samplePNG], rotations: [], to: destination)

        #expect(alert.isSuccess)
        #expect(alert.output == destination)
    }

    @Test func splitReportsTheFolder() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let alert = await ExportService().splitPDFs(urls: [TestFixtures.samplePDF], rotations: [], into: directory)

        #expect(alert.isSuccess)
        #expect(alert.output == directory)
    }

    @Test func failedMergeHasNoOutput() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let missing = directory.appendingPathComponent("missing.pdf")

        let alert = await ExportService().mergePDFs(
            urls: [missing],
            rotations: [],
            to: directory.appendingPathComponent("merged.pdf")
        )

        #expect(!alert.isSuccess)
        #expect(alert.output == nil)
    }
}
