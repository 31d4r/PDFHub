import Foundation
import PDFKit
import Testing
@testable import Beaver

struct ExportServiceTests {
    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BeaverExportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func mergeWritesAllPages() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("merged.pdf")
        let sources = [TestFixtures.samplePDF, TestFixtures.sample2PDF]
        let expectedPages = sources.compactMap { PDFDocument(url: $0)?.pageCount }.reduce(0, +)

        let alert = await ExportService().mergePDFs(urls: sources, rotationAngles: [:], to: destination)

        #expect(alert.isSuccess)
        let merged = try #require(PDFDocument(url: destination))
        #expect(merged.pageCount == expectedPages)
    }

    @Test func splitWritesOneFilePerPage() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let expectedPages = try #require(PDFDocument(url: TestFixtures.sample2PDF)).pageCount

        let alert = await ExportService().splitPDFs(urls: [TestFixtures.sample2PDF], rotationAngles: [:], into: directory)

        #expect(alert.isSuccess)
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".pdf") }
        #expect(files.count == expectedPages)
    }

    @Test func convertWritesOnePagePerImage() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("images.pdf")

        let alert = await ExportService().convertImages(urls: [TestFixtures.samplePNG], to: destination)

        #expect(alert.isSuccess)
        #expect(try #require(PDFDocument(url: destination)).pageCount == 1)
    }

    @Test func mergeOfUnreadableFilesFails() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("merged.pdf")
        let missing = directory.appendingPathComponent("missing.pdf")

        let alert = await ExportService().mergePDFs(urls: [missing], rotationAngles: [:], to: destination)

        #expect(!alert.isSuccess)
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }
}
