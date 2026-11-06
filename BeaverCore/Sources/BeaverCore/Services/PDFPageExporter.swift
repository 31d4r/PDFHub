import CoreGraphics
import Foundation
import ImageIO
import PDFKit

/// Takes pages out of a PDF, on the device: as a new PDF, or drawn as PNG or JPEG images.
/// The user's file and page rotations are applied on top of each page's saved rotation, and the
/// source file is never changed.
///
/// Images are drawn at 200 pixels per inch. An A4 or Letter page becomes about 1,650 × 2,340
/// pixels: sharp on Retina screens and readable when printed or zoomed, while a text page stays
/// a few hundred kilobytes as PNG. Very large pages are scaled down so the long side stays
/// within `maxPixelDimension`, which keeps memory in check for posters and drawings.
public struct PDFPageExporter: Sendable {
    /// Pixels per inch for page images.
    public static let imageResolution: CGFloat = 200
    /// The longest side of a page image, in pixels.
    public static let maxPixelDimension: CGFloat = 8_000
    /// JPEG quality, from 0 to 1: small files with no visible blocking on text.
    public static let jpegQuality: CGFloat = 0.85

    /// A source PDF opened for export, with copies of the chosen pages already turned.
    public struct PreparedPages {
        /// Kept open while the pages are drawn.
        public let document: PDFDocument
        /// Zero-based index in the source and the turned copy of that page, in export order.
        public let pages: [(index: Int, page: PDFPage)]
    }

    public init() {}

    // MARK: - Opening

    /// Opens the PDF and copies the chosen pages, turned. Pages outside the document are left
    /// out, and a page chosen twice is exported once.
    public func prepare(_ source: PageExportSource) throws(PageExportError) -> PreparedPages {
        let document = try open(source.url)
        let indexes = Self.pageIndexes(source.pages, pageCount: document.pageCount)
        let pages: [(index: Int, page: PDFPage)] = indexes.compactMap { index in
            guard let page = document.page(at: index)?.copy() as? PDFPage else { return nil }
            page.rotation = source.rotation.degrees(forPage: index, savedRotation: page.rotation)
            return (index, page)
        }
        guard !pages.isEmpty else { throw .noPages(source.url) }
        return PreparedPages(document: document, pages: pages)
    }

    /// How many files or pages an export of `source` makes.
    public func pageCount(of source: PageExportSource) throws(PageExportError) -> Int {
        let document = try open(source.url)
        let count = Self.pageIndexes(source.pages, pageCount: document.pageCount).count
        guard count > 0 else { throw .noPages(source.url) }
        return count
    }

    /// Fails for files that aren't PDFs, that need a password, or that have no pages. PDFs with
    /// only an owner password (printing or copying limits) open with an empty password.
    public func open(_ url: URL) throws(PageExportError) -> PDFDocument {
        guard let document = PDFDocument(url: url) else { throw .unreadable(url) }
        if document.isLocked && !document.unlock(withPassword: "") {
            throw .locked(url)
        }
        guard document.pageCount > 0 else { throw .noPages(url) }
        return document
    }

    /// `pages` in order without repeats and within the document, or every page for `nil`.
    public static func pageIndexes(_ pages: [Int]?, pageCount: Int) -> [Int] {
        guard let pages else { return Array(0..<max(pageCount, 0)) }
        var seen = Set<Int>()
        return pages.filter { (0..<pageCount).contains($0) && seen.insert($0).inserted }
    }

    // MARK: - PDF

    /// A new PDF with only the chosen pages, in the order given.
    public func extractPDF(_ source: PageExportSource) throws(PageExportError) -> PDFDocument {
        let prepared = try prepare(source)
        let extracted = PDFDocument()
        for (_, page) in prepared.pages {
            extracted.insert(page, at: extracted.pageCount)
        }
        return extracted
    }

    // MARK: - Images

    /// The page drawn on white, as PNG or JPEG data, at `imageResolution`.
    public func imageData(
        for page: PDFPage,
        format: PageExportFormat,
        resolution: CGFloat = Self.imageResolution
    ) -> Data? {
        guard format.isImage, let image = Self.render(page, resolution: resolution) else { return nil }
        return Self.encode(image, as: format, resolution: resolution)
    }

    /// Draws the page as it's shown, with its rotation and annotations, on an opaque white page.
    public static func render(_ page: PDFPage, resolution: CGFloat = imageResolution) -> CGImage? {
        let box = page.bounds(for: .cropBox)
        let shown = RotationAngle(normalizing: page.rotation).rotatedSize(box.size)
        guard shown.width > 0, shown.height > 0, resolution > 0 else { return nil }

        let scale = min(resolution / 72, maxPixelDimension / max(shown.width, shown.height))
        let width = max(1, Int((shown.width * scale).rounded()))
        let height = max(1, Int((shown.height * scale).rounded()))

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.scaleBy(x: CGFloat(width) / shown.width, y: CGFloat(height) / shown.height)
        // PDFKit applies the page's rotation and crop box itself.
        page.draw(with: .cropBox, to: context)
        return context.makeImage()
    }

    static func encode(_ image: CGImage, as format: PageExportFormat, resolution: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            format.contentType.identifier as CFString,
            1,
            nil
        ) else { return nil }

        var properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: resolution,
            kCGImagePropertyDPIHeight: resolution,
        ]
        if format == .jpeg {
            properties[kCGImageDestinationLossyCompressionQuality] = jpegQuality
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    // MARK: - File names

    /// `<name>_page-<n>.png`, with `n` counted from 1, like Split's `<name>_page-<n>.pdf`.
    public static func imageFileName(sourceURL: URL, pageIndex: Int, format: PageExportFormat) -> String {
        "\(stem(of: sourceURL))_page-\(pageIndex + 1).\(format.fileExtension)"
    }

    /// `<name>_page-3.pdf` for one page, `<name>_pages-2-5.pdf` for a run of pages in order,
    /// and `<name>_pages.pdf` for any other choice.
    public static func pdfFileName(sourceURL: URL, pages: [Int]) -> String {
        let stem = stem(of: sourceURL)
        guard let first = pages.first, let last = pages.last else { return "\(stem)_pages.pdf" }
        if pages.count == 1 {
            return "\(stem)_page-\(first + 1).pdf"
        }
        let isRun = zip(pages, pages.dropFirst()).allSatisfy { $1 == $0 + 1 }
        return isRun ? "\(stem)_pages-\(first + 1)-\(last + 1).pdf" : "\(stem)_pages.pdf"
    }

    /// `<name>_images`, the folder iPhone and iPad save several page images into.
    public static func imageFolderName(sourceURL: URL) -> String {
        "\(stem(of: sourceURL))_images"
    }

    private static func stem(of url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }
}
