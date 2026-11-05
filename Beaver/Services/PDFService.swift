import Foundation
import PDFKit

protocol PDFServiceProtocol {
    func loadPDF(from url: URL) -> PDFDocument?
    func mergePDFs(urls: [URL], rotationAngles: [URL: Int]) -> PDFDocument?
    func splitPDF(urls: [URL], rotationAngles: [URL: Int]) -> [PDFDocument]
}

struct PDFService: PDFServiceProtocol {
    func loadPDF(from url: URL) -> PDFDocument? {
        return PDFDocument(url: url)
    }
    
    func mergePDFs(urls: [URL], rotationAngles: [URL: Int]) -> PDFDocument? {
        guard !urls.isEmpty else { return nil }
        
        let mergedPDF = PDFDocument()
        
        for url in urls {
            guard let pdf = loadPDF(from: url) else { continue }
            let rotationAngle = rotationAngles[url] ?? 0
            
            addPages(from: pdf, to: mergedPDF, withRotation: rotationAngle)
        }
        
        return mergedPDF.pageCount > 0 ? mergedPDF : nil
    }
    
    func splitPDF(urls: [URL], rotationAngles: [URL: Int]) -> [PDFDocument] {
        var allSplitPDFs: [PDFDocument] = []
        
        for url in urls {
            guard let pdf = loadPDF(from: url) else { continue }
            let rotationAngle = rotationAngles[url] ?? 0
            
            let splitDocuments = createSinglePagePDFs(from: pdf, withRotation: rotationAngle)
            allSplitPDFs.append(contentsOf: splitDocuments)
        }
        
        return allSplitPDFs
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

