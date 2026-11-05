import BeaverCore
import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import Testing
import UniformTypeIdentifiers

struct ImageConversionTests {
    private func writeImage(
        width: Int,
        height: Int,
        type: UTType,
        properties: [CFString: Any] = [:]
    ) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BeaverImage-\(UUID().uuidString)")
            .appendingPathExtension(for: type)
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, TestImages.solid(width: width, height: height), properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    private func pageSize(of document: PDFDocument?) throws -> CGSize {
        let page = try #require(document?.page(at: 0))
        return page.bounds(for: .mediaBox).size
    }

    @Test func pageSizeUsesPointsAt72DPI() throws {
        let url = try writeImage(width: 200, height: 100, type: .png)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = ImageService().convertImagesToPDF(imageUrls: [url])

        #expect(try pageSize(of: result.document) == CGSize(width: 200, height: 100))
    }

    @Test func pageSizeHonoursImageResolution() throws {
        let url = try writeImage(
            width: 288,
            height: 144,
            type: .png,
            properties: [kCGImagePropertyDPIWidth: 144, kCGImagePropertyDPIHeight: 144]
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let result = ImageService().convertImagesToPDF(imageUrls: [url])

        #expect(try pageSize(of: result.document) == CGSize(width: 144, height: 72))
    }

    @Test func exifOrientationTurnsThePage() throws {
        // Orientation 6 means the stored pixels must be rotated 90° clockwise to display.
        let url = try writeImage(
            width: 200,
            height: 100,
            type: .jpeg,
            properties: [kCGImagePropertyOrientation: 6]
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let result = ImageService().convertImagesToPDF(imageUrls: [url])

        #expect(try pageSize(of: result.document) == CGSize(width: 100, height: 200))
    }

    @Test func keepsOrderAndSkipsUnreadableFiles() throws {
        let wide = try writeImage(width: 40, height: 20, type: .png)
        let tall = try writeImage(width: 20, height: 40, type: .png)
        let missing = URL(fileURLWithPath: "/tmp/beaver-missing-\(UUID().uuidString).png")
        defer {
            try? FileManager.default.removeItem(at: wide)
            try? FileManager.default.removeItem(at: tall)
        }

        let result = ImageService().convertImagesToPDF(imageUrls: [wide, missing, tall])

        let document = try #require(result.document)
        #expect(document.pageCount == 2)
        #expect(document.page(at: 0)?.bounds(for: .mediaBox).size == CGSize(width: 40, height: 20))
        #expect(document.page(at: 1)?.bounds(for: .mediaBox).size == CGSize(width: 20, height: 40))
        #expect(result.skippedURLs == [missing])
    }
}
