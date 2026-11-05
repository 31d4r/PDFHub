import Foundation
import AppKit
import PDFKit

protocol ImageServiceProtocol {
    func loadImage(from url: URL) -> NSImage?
    func convertImagesToPDF(imageUrls: [URL]) -> PDFDocument?
}

struct ImageService: ImageServiceProtocol {
    func loadImage(from url: URL) -> NSImage? {
        return NSImage(contentsOf: url)
    }
    
    func convertImagesToPDF(imageUrls: [URL]) -> PDFDocument? {
        let pdfDocument = PDFDocument()
        
        for (index, imageUrl) in imageUrls.enumerated() {
            if let image = loadImage(from: imageUrl),
               let pdfPage = PDFPage(image: image) {
                pdfDocument.insert(pdfPage, at: index)
            }
        }
        
        return pdfDocument.pageCount > 0 ? pdfDocument : nil
    }
}

