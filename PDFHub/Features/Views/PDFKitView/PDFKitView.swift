import SwiftUI
import PDFKit

struct PDFKitView: NSViewRepresentable {
    let url: URL?
    @Binding var rotationAngle: Int
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displaysPageBreaks = true
        pdfView.displayDirection = .vertical
        
        if let url = url {
            pdfView.document = PDFDocument(url: url)
        }
        
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        if let url = url {
            nsView.document = PDFDocument(url: url)
        }
        
        if let document = nsView.document {
            rotateDocument(document, by: rotationAngle)
        }
    }
    
    private func rotateDocument(_ document: PDFDocument, by angle: Int) {
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                page.rotation = (page.rotation + angle) % 360
            }
        }
    }
}
