import Foundation
import PDFKit

/// Builds PDFs from a mix of PDFs and images, in the order given: one combined document,
/// or one single-page document per page. Stops early when the current task is cancelled.
public struct DocumentComposer: Sendable {
    private let pdfService: any PDFServiceProtocol
    private let imageService: any ImageServiceProtocol

    public init(
        pdfService: any PDFServiceProtocol = PDFService(),
        imageService: any ImageServiceProtocol = ImageService()
    ) {
        self.pdfService = pdfService
        self.imageService = imageService
    }

    /// Every page of every readable source, in order. Images become one page each.
    public func combine(_ sources: [ExportSource]) -> PDFMergeResult {
        let combined = PDFDocument()
        var skippedURLs: [URL] = []

        for source in sources {
            if Task.isCancelled { break }
            guard let document = document(for: source) else {
                skippedURLs.append(source.url)
                continue
            }
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index)?.copy() as? PDFPage else { continue }
                combined.insert(page, at: combined.pageCount)
            }
        }

        return PDFMergeResult(
            document: combined.pageCount > 0 ? combined : nil,
            skippedURLs: skippedURLs
        )
    }

    /// One document per page: `<name>_page-<n>.pdf` for PDF pages, `<name>.pdf` for an image.
    public func split(_ sources: [ExportSource]) -> PDFSplitResult {
        var pages: [SplitPage] = []
        var skippedURLs: [URL] = []

        for source in sources {
            if Task.isCancelled { break }
            switch source {
            case .pdf(let url, let rotation):
                let result = pdfService.splitPDF(urls: [url], rotations: [rotation])
                pages.append(contentsOf: result.pages)
                skippedURLs.append(contentsOf: result.skippedURLs)
            case .image(let url, _):
                guard let document = document(for: source) else {
                    skippedURLs.append(url)
                    continue
                }
                pages.append(SplitPage(document: document, fileName: SplitPage.fileName(imageURL: url)))
            }
        }

        return PDFSplitResult(pages: pages, skippedURLs: skippedURLs)
    }

    private func document(for source: ExportSource) -> PDFDocument? {
        switch source {
        case .pdf(let url, let rotation):
            return pdfService.mergePDFs(urls: [url], rotations: [rotation]).document
        case .image(let url, let rotation):
            return imageService.convertImagesToPDF(imageUrls: [url], rotations: [rotation]).document
        }
    }
}

public extension SplitPage {
    /// `<image name>.pdf`.
    static func fileName(imageURL: URL) -> String {
        imageURL.deletingPathExtension().lastPathComponent + ".pdf"
    }
}
