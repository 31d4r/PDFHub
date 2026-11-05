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

final class MockFileIOService: FileIOServiceProtocol {
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

final class MockImageService: ImageServiceProtocol {
    var imagesByURL: [URL: NSImage] = [:]
    var convertedDocument: PDFDocument?

    func loadImage(from url: URL) -> NSImage? {
        imagesByURL[url]
    }

    func convertImagesToPDF(imageUrls: [URL]) -> ImageConversionResult {
        ImageConversionResult(document: convertedDocument, skippedURLs: [])
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
