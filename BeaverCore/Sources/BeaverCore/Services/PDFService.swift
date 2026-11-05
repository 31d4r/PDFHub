import Foundation
import PDFKit

public protocol PDFServiceProtocol: Sendable {
    func loadPDF(from url: URL) -> PDFDocument?
    func mergePDFs(urls: [URL], rotationAngles: [URL: Int]) -> PDFMergeResult
    func splitPDF(urls: [URL], rotationAngles: [URL: Int]) -> PDFSplitResult
}

public struct PDFMergeResult {
    /// `nil` when no pages could be read.
    public let document: PDFDocument?
    /// Files that could not be opened as PDFs and were left out.
    public let skippedURLs: [URL]

    public init(document: PDFDocument?, skippedURLs: [URL]) {
        self.document = document
        self.skippedURLs = skippedURLs
    }
}

public struct PDFSplitResult {
    public let pages: [SplitPage]
    /// Files that could not be opened as PDFs and were left out.
    public let skippedURLs: [URL]

    public init(pages: [SplitPage], skippedURLs: [URL]) {
        self.pages = pages
        self.skippedURLs = skippedURLs
    }
}

/// One page split out of a source PDF, with the file name it should be saved under.
public struct SplitPage {
    public let document: PDFDocument
    public let fileName: String

    public init(document: PDFDocument, fileName: String) {
        self.document = document
        self.fileName = fileName
    }

    /// `<source name>_page-<n>.pdf`, with `n` starting at 1.
    public static func fileName(sourceURL: URL, pageNumber: Int) -> String {
        let stem = sourceURL.deletingPathExtension().lastPathComponent
        return "\(stem)_page-\(pageNumber).pdf"
    }
}

public struct PDFService: PDFServiceProtocol {
    public init() {}

    public func loadPDF(from url: URL) -> PDFDocument? {
        return PDFDocument(url: url)
    }
    
    public func mergePDFs(urls: [URL], rotationAngles: [URL: Int]) -> PDFMergeResult {
        guard !urls.isEmpty else { return PDFMergeResult(document: nil, skippedURLs: []) }

        let mergedPDF = PDFDocument()
        var skippedURLs: [URL] = []

        for url in urls {
            guard let pdf = loadPDF(from: url) else {
                skippedURLs.append(url)
                continue
            }
            let rotationAngle = rotationAngles[url] ?? 0
            
            addPages(from: pdf, to: mergedPDF, withRotation: rotationAngle)
        }
        
        return PDFMergeResult(
            document: mergedPDF.pageCount > 0 ? mergedPDF : nil,
            skippedURLs: skippedURLs
        )
    }
    
    public func splitPDF(urls: [URL], rotationAngles: [URL: Int]) -> PDFSplitResult {
        var allSplitPages: [SplitPage] = []
        var skippedURLs: [URL] = []

        for url in urls {
            guard let pdf = loadPDF(from: url) else {
                skippedURLs.append(url)
                continue
            }
            let rotationAngle = rotationAngles[url] ?? 0

            let splitDocuments = createSinglePagePDFs(from: pdf, withRotation: rotationAngle)
            for (index, document) in splitDocuments.enumerated() {
                allSplitPages.append(SplitPage(
                    document: document,
                    fileName: SplitPage.fileName(sourceURL: url, pageNumber: index + 1)
                ))
            }
        }

        return PDFSplitResult(pages: allSplitPages, skippedURLs: skippedURLs)
    }
    
    private func addPages(from sourcePDF: PDFDocument, to targetPDF: PDFDocument, withRotation rotation: Int) {
        for pageIndex in 0..<sourcePDF.pageCount {
            guard let page = copiedPage(at: pageIndex, of: sourcePDF, addingRotation: rotation) else { continue }
            targetPDF.insert(page, at: targetPDF.pageCount)
        }
    }

    private func createSinglePagePDFs(from pdf: PDFDocument, withRotation rotation: Int) -> [PDFDocument] {
        var singlePagePDFs: [PDFDocument] = []

        for pageIndex in 0..<pdf.pageCount {
            guard let page = copiedPage(at: pageIndex, of: pdf, addingRotation: rotation) else { continue }

            let singlePagePDF = PDFDocument()
            singlePagePDF.insert(page, at: 0)
            singlePagePDFs.append(singlePagePDF)
        }

        return singlePagePDFs
    }

    /// Copies a page so the source document is never mutated, and adds the user's
    /// rotation on top of the rotation already stored in the page.
    private func copiedPage(at index: Int, of document: PDFDocument, addingRotation rotation: Int) -> PDFPage? {
        guard let page = document.page(at: index)?.copy() as? PDFPage else { return nil }
        page.rotation = RotationAngle.normalized(page.rotation + rotation)
        return page
    }
}

