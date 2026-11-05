import Foundation
import PDFKit
import Testing
@testable import Beaver

@Suite("Split file naming")
struct SplitNamingTests {
    @Test("Split pages are named after their source file, starting at page 1")
    func namesFollowSource() {
        let split = PDFService().splitPDF(
            urls: [TestFixtures.samplePDF, TestFixtures.sample2PDF],
            rotationAngles: [:]
        ).pages

        #expect(split.map(\.fileName) == [
            "sample_page-1.pdf",
            "sample_page-2.pdf",
            "sample2_page-1.pdf",
        ])
    }

    @Test("Existing files are never overwritten")
    func existingFilesGetSuffix() throws {
        let directory = URL(fileURLWithPath: "/tmp/beaver-out")
        let io = MockFileIOService()
        io.existingURLs = [
            directory.appendingPathComponent("sample_page-1.pdf"),
            directory.appendingPathComponent("sample_page-1 (2).pdf"),
        ]
        let writer = PDFFileWriterService(fileIOService: io)
        let document = try #require(PDFDocument(url: TestFixtures.sample2PDF))

        let result = writer.savePDFDocuments(
            [SplitPage(document: document, fileName: "sample_page-1.pdf")],
            to: directory
        )

        #expect(result.isCompleteSuccess)
        #expect(io.writtenURLs.map(\.lastPathComponent) == ["sample_page-1 (3).pdf"])
    }

    @Test("Two sources with the same name in one batch do not clash")
    func duplicateNamesInBatch() throws {
        let io = MockFileIOService()
        let writer = PDFFileWriterService(fileIOService: io)
        let document = try #require(PDFDocument(url: TestFixtures.sample2PDF))
        let pages = [
            SplitPage(document: document, fileName: "report_page-1.pdf"),
            SplitPage(document: document, fileName: "report_page-1.pdf"),
        ]

        _ = writer.savePDFDocuments(pages, to: URL(fileURLWithPath: "/tmp/beaver-out"))

        #expect(io.writtenURLs.map(\.lastPathComponent) == [
            "report_page-1.pdf",
            "report_page-1 (2).pdf",
        ])
    }

    @Test("Writing to a real folder keeps the original file intact")
    func realFolderCollision() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("beaver-split-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let existing = directory.appendingPathComponent("sample_page-1.pdf")
        try Data("keep me".utf8).write(to: existing)

        let split = PDFService().splitPDF(urls: [TestFixtures.samplePDF], rotationAngles: [:]).pages
        let result = PDFFileWriterService().savePDFDocuments(split, to: directory)

        #expect(result.successCount == 2)
        #expect(try Data(contentsOf: existing) == Data("keep me".utf8))
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        #expect(names == ["sample_page-1 (2).pdf", "sample_page-1.pdf", "sample_page-2.pdf"])
    }
}
