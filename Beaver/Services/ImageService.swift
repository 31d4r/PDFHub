import AppKit
import Foundation
import ImageIO
import PDFKit

protocol ImageServiceProtocol: Sendable {
    /// A preview no larger than `maxPixelSize` on its longest side, with EXIF
    /// orientation applied. `nil` when the file is not a readable image.
    func thumbnail(for url: URL, maxPixelSize: Int) -> CGImage?
    func convertImagesToPDF(imageUrls: [URL]) -> ImageConversionResult
}

struct ImageConversionResult {
    /// `nil` when none of the images could be converted.
    let document: PDFDocument?
    /// Images that could not be read and were left out.
    let skippedURLs: [URL]
}

struct ImageService: ImageServiceProtocol {
    func thumbnail(for url: URL, maxPixelSize: Int) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            return nil
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions)
    }


    func convertImagesToPDF(imageUrls: [URL]) -> ImageConversionResult {
        let pdfDocument = PDFDocument()
        var skippedURLs: [URL] = []

        for imageUrl in imageUrls {
            if let image = NSImage(contentsOf: imageUrl),
               let pdfPage = PDFPage(image: image) {
                pdfDocument.insert(pdfPage, at: pdfDocument.pageCount)
            } else {
                skippedURLs.append(imageUrl)
            }
        }

        return ImageConversionResult(
            document: pdfDocument.pageCount > 0 ? pdfDocument : nil,
            skippedURLs: skippedURLs
        )
    }
}

