import BeaverCore
import AppKit
import Foundation
import PDFKit
import UniformTypeIdentifiers
@testable import Beaver

final class MockFilePanelService: FilePanelServiceProtocol {
    var openURLs: [URL] = []
    var saveURL: URL?
    var directoryURL: URL?

    func openFilePanel(
        contentTypes: [UTType],
        multipleSelection: Bool
    ) -> [URL] {
        openURLs
    }

    func showSavePanel(
        defaultName: String,
        prompt: String,
        allowedTypes: [UTType]
    ) -> URL? {
        saveURL
    }

    func showDirectoryPanel(prompt: String) -> URL? {
        directoryURL
    }
}

// Tests drive this mock from one task at a time.
final class MockFileIOService: FileIOServiceProtocol, @unchecked Sendable {
    var writtenURLs: [URL] = []
    var existingURLs: Set<URL> = []
    var shouldFail = false

    func fileExists(at url: URL) -> Bool {
        existingURLs.contains(url)
    }

    func write(
        data: Data,
        to url: URL
    ) throws {
        if shouldFail {
            throw NSError(
                domain: "MockFileIOService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Write failed"]
            )
        }
        writtenURLs.append(url)
    }
}

// Tests drive this mock from one task at a time.
final class MockImageService: ImageServiceProtocol, @unchecked Sendable {
    var thumbnailsByURL: [URL: CGImage] = [:]
    var convertedDocument: PDFDocument?

    func thumbnail(for url: URL, maxPixelSize: Int) -> CGImage? {
        thumbnailsByURL[url]
    }

    func convertImagesToPDF(imageUrls: [URL]) -> ImageConversionResult {
        ImageConversionResult(document: convertedDocument, skippedURLs: [])
    }
}

enum TestImages {
    static func solid(width: Int, height: Int) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
}

enum TestFixtures {
    static var directory: URL {
        let bundle = Bundle(for: MockFilePanelService.self)
        if let url = bundle.url(
            forResource: "sample",
            withExtension: "pdf",
            subdirectory: "Fixtures"
        ) {
            return url.deletingLastPathComponent()
        }
        if let url = bundle.url(
            forResource: "sample",
            withExtension: "pdf"
        ) {
            return url.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }

    static var samplePDF: URL {
        directory.appendingPathComponent("sample.pdf")
    }

    static var sample2PDF: URL {
        directory.appendingPathComponent("sample2.pdf")
    }

    static var samplePNG: URL {
        directory.appendingPathComponent("sample.png")
    }
}
