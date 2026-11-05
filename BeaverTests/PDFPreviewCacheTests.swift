import BeaverCore
import Foundation
import PDFKit
import Testing

/// The grid's first-page previews: drawn once, counted correctly, and bounded in memory.
struct PDFPreviewCacheTests {
    @Test func previewDrawsTheFirstPageAndCountsPages() async throws {
        let cache = PDFPreviewCache()
        let expected = try #require(PDFDocument(url: TestFixtures.samplePDF)).pageCount

        let preview = await cache.preview(for: TestFixtures.samplePDF, maxPixelSize: 120)

        #expect(preview.pageCount == expected)
        let image = try #require(preview.image)
        #expect(max(image.width, image.height) <= 120)
    }

    @Test func previewsAreCachedPerFile() async {
        let cache = PDFPreviewCache()
        #expect(await !cache.contains(TestFixtures.samplePDF))

        _ = await cache.preview(for: TestFixtures.samplePDF, maxPixelSize: 64)

        #expect(await cache.contains(TestFixtures.samplePDF))
    }

    @Test func leastRecentlyUsedPreviewIsEvicted() async {
        let cache = PDFPreviewCache(capacity: 2)
        let third = URL(fileURLWithPath: "/tmp/beaver-missing-\(UUID().uuidString).pdf")

        _ = await cache.preview(for: TestFixtures.samplePDF, maxPixelSize: 32)
        _ = await cache.preview(for: TestFixtures.sample2PDF, maxPixelSize: 32)
        _ = await cache.preview(for: TestFixtures.samplePDF, maxPixelSize: 32)
        _ = await cache.preview(for: third, maxPixelSize: 32)

        #expect(await cache.contains(TestFixtures.samplePDF))
        #expect(await !cache.contains(TestFixtures.sample2PDF))
        #expect(await cache.contains(third))
    }

    @Test func unreadableFileHasNoPreviewAndNoPages() async {
        let cache = PDFPreviewCache()
        let missing = URL(fileURLWithPath: "/tmp/beaver-missing-\(UUID().uuidString).pdf")

        let preview = await cache.preview(for: missing, maxPixelSize: 32)

        #expect(preview.image == nil)
        #expect(preview.pageCount == 0)
    }
}
