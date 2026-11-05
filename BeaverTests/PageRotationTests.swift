import Foundation
import PDFKit
import Testing
@testable import Beaver

@Suite("Page rotation on export")
struct PageRotationTests {
    private let service = PDFService()

    /// Writes a copy of the 2-page sample whose pages already carry a 90° rotation.
    private func makePreRotatedPDF() throws -> URL {
        let document = try #require(PDFDocument(url: TestFixtures.samplePDF))
        for index in 0 ..< document.pageCount {
            document.page(at: index)?.rotation = 90
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("prerotated-\(UUID().uuidString).pdf")
        #expect(document.write(to: url))
        return url
    }

    @Test("Merge adds the user rotation to the page's own rotation")
    func mergeAddsRotation() throws {
        let url = try makePreRotatedPDF()
        defer { try? FileManager.default.removeItem(at: url) }

        let merged = try #require(service.mergePDFs(urls: [url], rotationAngles: [url: 90]).document)

        #expect(merged.pageCount == 2)
        #expect(merged.page(at: 0)?.rotation == 180)
        #expect(merged.page(at: 1)?.rotation == 180)
    }

    @Test("Split wraps the combined rotation past 360")
    func splitWrapsRotation() throws {
        let url = try makePreRotatedPDF()
        defer { try? FileManager.default.removeItem(at: url) }

        let split = service.splitPDF(urls: [url], rotationAngles: [url: 270]).pages

        #expect(split.count == 2)
        #expect(split.allSatisfy { $0.document.page(at: 0)?.rotation == 0 })
    }

    @Test("Merging the same file twice keeps every page")
    func mergeSameFileTwice() throws {
        let url = TestFixtures.samplePDF
        let merged = try #require(service.mergePDFs(urls: [url, url], rotationAngles: [:]).document)
        #expect(merged.pageCount == 4)
    }

    @Test("Applied rotation is normalised", arguments: [
        (RotationAngle.zero, 0, 0),
        (.ninety, 270, 0),
        (.oneEighty, 270, 90),
        (.twoSeventy, -90, 180),
    ])
    func appliedRotation(angle: RotationAngle, pageRotation: Int, expected: Int) {
        #expect(angle.applied(to: pageRotation) == expected)
    }
}
