import CoreGraphics
import Foundation
import ImageIO
import PDFKit

public protocol ImageServiceProtocol: Sendable {
    /// A preview no larger than `maxPixelSize` on its longest side, with EXIF
    /// orientation applied. `nil` when the file is not a readable image.
    func thumbnail(for url: URL, maxPixelSize: Int) -> CGImage?
    func convertImagesToPDF(imageUrls: [URL]) -> ImageConversionResult
}

public struct ImageConversionResult {
    /// `nil` when none of the images could be converted.
    public let document: PDFDocument?
    /// Images that could not be read and were left out.
    public let skippedURLs: [URL]

    public init(document: PDFDocument?, skippedURLs: [URL]) {
        self.document = document
        self.skippedURLs = skippedURLs
    }
}

/// Reads images with ImageIO and draws PDFs with Core Graphics, so it works on
/// macOS and iOS without AppKit or UIKit.
public struct ImageService: ImageServiceProtocol {
    public init() {}

    public func thumbnail(for url: URL, maxPixelSize: Int) -> CGImage? {
        guard let source = makeSource(for: url) else { return nil }
        return orientedImage(from: source, maxPixelSize: maxPixelSize)
    }

    public func convertImagesToPDF(imageUrls: [URL]) -> ImageConversionResult {
        let data = NSMutableData()
        var skippedURLs: [URL] = []
        var pageCount = 0

        guard
            let consumer = CGDataConsumer(data: data as CFMutableData),
            let context = CGContext(consumer: consumer, mediaBox: nil, nil)
        else {
            return ImageConversionResult(document: nil, skippedURLs: imageUrls)
        }

        for imageUrl in imageUrls {
            guard let page = fullSizePage(for: imageUrl) else {
                skippedURLs.append(imageUrl)
                continue
            }

            var mediaBox = CGRect(origin: .zero, size: page.size)
            let pageInfo = [kCGPDFContextMediaBox as String: Data(
                bytes: &mediaBox,
                count: MemoryLayout<CGRect>.size
            )] as CFDictionary
            context.beginPDFPage(pageInfo)
            context.draw(page.image, in: mediaBox)
            context.endPDFPage()
            pageCount += 1
        }
        context.closePDF()

        let document = pageCount > 0 ? PDFDocument(data: data as Data) : nil
        return ImageConversionResult(document: document, skippedURLs: skippedURLs)
    }

    // MARK: - Private

    private struct Page {
        let image: CGImage
        /// Page size in points, from the image's pixel size and resolution.
        let size: CGSize
    }

    private func makeSource(for url: URL) -> CGImageSource? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        return CGImageSourceCreateWithURL(url as CFURL, options)
    }

    /// The first frame, rotated by its EXIF orientation and at most `maxPixelSize` on its longest side.
    private func orientedImage(from source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    private func fullSizePage(for url: URL) -> Page? {
        guard
            let source = makeSource(for: url),
            CGImageSourceGetCount(source) > 0,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let pixelWidth = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
            let pixelHeight = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
            pixelWidth > 0, pixelHeight > 0,
            let image = orientedImage(from: source, maxPixelSize: max(pixelWidth, pixelHeight))
        else {
            return nil
        }

        let dpiWidth = Self.resolution(properties[kCGImagePropertyDPIWidth])
        let dpiHeight = Self.resolution(properties[kCGImagePropertyDPIHeight])
        // The DPI values describe the stored pixels, so swap them when EXIF orientation turned the image.
        let isQuarterTurned = image.width == pixelHeight && image.height == pixelWidth && pixelWidth != pixelHeight
        let (horizontalDPI, verticalDPI) = isQuarterTurned ? (dpiHeight, dpiWidth) : (dpiWidth, dpiHeight)
        let size = CGSize(
            width: CGFloat(image.width) * Self.pointsPerInch / horizontalDPI,
            height: CGFloat(image.height) * Self.pointsPerInch / verticalDPI
        )
        return Page(image: image, size: size)
    }

    private static let pointsPerInch: CGFloat = 72

    /// Treats a missing or invalid resolution as 72 dpi, like AppKit does.
    private static func resolution(_ value: Any?) -> CGFloat {
        guard let dpi = (value as? NSNumber)?.doubleValue, dpi > 0 else { return pointsPerInch }
        return CGFloat(dpi)
    }
}
