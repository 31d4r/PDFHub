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
            guard let page = sourcePDF.page(at: pageIndex) else { continue }
            
            targetPDF.insert(page, at: targetPDF.pageCount)
            if let insertedPage = targetPDF.page(at: targetPDF.pageCount - 1) {
                insertedPage.rotation = rotation
            }
        }
    }
    
    private func createSinglePagePDFs(from pdf: PDFDocument, withRotation rotation: Int) -> [PDFDocument] {
        var singlePagePDFs: [PDFDocument] = []
        
        for pageIndex in 0..<pdf.pageCount {
            guard let page = pdf.page(at: pageIndex) else { continue }
            
            let singlePagePDF = PDFDocument()
            singlePagePDF.insert(page, at: 0)
            if let insertedPage = singlePagePDF.page(at: 0) {
                insertedPage.rotation = rotation
            }
            singlePagePDFs.append(singlePagePDF)
        }
        
        return singlePagePDFs
    }
}

