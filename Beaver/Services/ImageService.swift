import Foundation
import AppKit
import PDFKit

protocol ImageServiceProtocol {
    func loadImage(from url: URL) -> NSImage?
    func convertImagesToPDF(imageUrls: [URL]) -> ImageConversionResult
}

struct ImageConversionResult {
    /// `nil` when none of the images could be converted.
    let document: PDFDocument?
    /// Images that could not be read and were left out.
    let skippedURLs: [URL]
}

struct ImageService: ImageServiceProtocol {
    func loadImage(from url: URL) -> NSImage? {
        return NSImage(contentsOf: url)
    }
    
    func convertImagesToPDF(imageUrls: [URL]) -> ImageConversionResult {
        let pdfDocument = PDFDocument()
        var skippedURLs: [URL] = []

        for imageUrl in imageUrls {
            if let image = loadImage(from: imageUrl),
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

