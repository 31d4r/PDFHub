import Foundation
import PDFKit
import Testing
@testable import Beaver

@Suite("Unreadable files and write errors")
struct SkippedFilesTests {
    private let missing = URL(fileURLWithPath: "/tmp/beaver-missing-\(UUID().uuidString).pdf")

    @Test("Merge reports files it could not read")
    func mergeReportsSkipped() {
        let result = PDFService().mergePDFs(urls: [TestFixtures.samplePDF, missing], rotationAngles: [:])
        #expect(result.document?.pageCount == 2)
        #expect(result.skippedURLs == [missing])
    }

    @Test("Split reports files it could not read")
    func splitReportsSkipped() {
        let result = PDFService().splitPDF(urls: [missing, TestFixtures.sample2PDF], rotationAngles: [:])
        #expect(result.pages.count == 1)
        #expect(result.skippedURLs == [missing])
    }

    @Test("Alert text lists skipped files")
    func alertMentionsSkipped() {
        let message = DesignSystem.Alerts.message("Done", skipped: [missing])
        #expect(message.hasPrefix("Done"))
        #expect(message.contains(missing.lastPathComponent))
        #expect(DesignSystem.Alerts.message("Done", skipped: []) == "Done")
    }

    @Test("Writer errors have a readable description")
    func writerErrorDescription() {
        let error: Error = PDFFileWriterError.failedToCreateData
        #expect(error.localizedDescription == "The PDF data could not be created.")
    }

    @Test("Atomic write replaces the whole file")
    func atomicWrite() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("beaver-atomic-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: url) }
        let io = FileIOService()
        try io.write(data: Data(repeating: 1, count: 64), to: url)
        try io.write(data: Data([2]), to: url)
        #expect(try Data(contentsOf: url) == Data([2]))
        #expect(io.fileExists(at: url))
    }
}
