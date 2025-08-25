import AsyncReactor
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

class PDFHubReactor: AsyncReactor {
    enum Action {
        case selectPDF
        case mergePDF([URL])
        case splitPDF([URL])
        case deletePDF(UUID)
        
        case selectImages
        case convertImagesToPDF([URL])
        case deleteImage(Int)
        
        case showAlert(
            message: String,
            success: Bool
        )
        case dismissAlert
    }

    enum SyncAction {
        case didUserSelectPDF([PDF])
        case didMergePDF(PDFDocument?)
        case didSplitPDFs([PDFDocument])
        case didChangePDFRotation(Int)
        
        case didUserSelectImages([NSImage])
        case didChangeImageURLs([URL])
        
        case didExportAlertPresent(Bool)
    }
    
    struct State {
        var selectedPDFs: [PDF] = []
        var mergedPDF: PDFDocument?
        var splitPDFs: [PDFDocument] = []
        var rotationAngle = 0
        
        var selectedImages = [NSImage]()
        var imageURLs = [URL]()
        
        var isExportAlertPresented = false
        var exportMessage = ""
        var exportSuccess = false
    }
    
    @Published private(set) var state: State
    
    init() {
        self.state = State()
    }
    
    func action(_ action: Action) async {
        switch action {
        case .selectPDF:
            selectPDF()
        case .mergePDF(let urls):
            state.mergedPDF = mergePDFs(urls: urls)
        case .splitPDF(let urls):
            state.splitPDFs = splitPDF(urls: urls)
        case .deletePDF(let id):
            deletePDF(with: id)
        case .selectImages:
            selectImages()
        case .convertImagesToPDF(let urls):
            convertImagesToPDF(imageUrls: urls)
        case .deleteImage(let index):
            deleteImage(at: index)
        case .showAlert(let message, let success):
            state.exportMessage = message
            state.exportSuccess = success
            state.isExportAlertPresented = true
        case .dismissAlert:
            state.isExportAlertPresented = false
        }
    }
    
    func action(_ action: SyncAction) {
        switch action {
        case .didUserSelectPDF(let pdfs):
            state.selectedPDFs = pdfs
        case .didMergePDF(let pdfDocument):
            state.mergedPDF = pdfDocument
        case .didSplitPDFs(let pdfDocuments):
            state.splitPDFs = pdfDocuments
        case .didUserSelectImages(let images):
            state.selectedImages = images
        case .didChangeImageURLs(let urls):
            state.imageURLs = urls
        case .didExportAlertPresent(let present):
            state.isExportAlertPresented = present
        case .didChangePDFRotation(let rotation):
            state.rotationAngle = rotation
        }
    }
    
    func selectPDF() {
        let urls = openFilePanel(
            contentTypes: [.pdf],
            multipleSelection: true
        )
        let newPDFs = urls.map {
            PDF(
                pdfURL: $0,
                rotationAngle: 0
            )
        }
        
        for newPDF in newPDFs {
            if !state.selectedPDFs.contains(where: { $0.pdfURL == newPDF.pdfURL }) {
                state.selectedPDFs.append(newPDF)
            }
        }
    }
    
    func mergePDFs(
        urls: [URL]
    ) -> PDFDocument? {
        let mergedPDF = PDFDocument()
        
        for (_, url) in urls.enumerated() {
            if let pdf = PDFDocument(url: url) {
                let rotationAngle = state.selectedPDFs.first(where: { $0.pdfURL == url })?.rotationAngle ?? 0
                
                for i in 0..<pdf.pageCount {
                    if let page = pdf.page(at: i) {
                        page.rotation = rotationAngle
                        mergedPDF.insert(
                            page,
                            at: mergedPDF.pageCount
                        )
                    }
                }
            }
        }
        
        if mergedPDF.pageCount > 0 {
            if let saveURL = showSavePanel(
                defaultName: "merged.pdf",
                prompt: "Save Merged PDF",
                allowedTypes: [.pdf]
            ) {
                savePDFDocument(
                    mergedPDF,
                    to: saveURL,
                    successMessage: "Merged PDF successfully saved at \(saveURL.lastPathComponent)"
                )
            }
        }
        
        return mergedPDF
    }
    
    func splitPDF(
        urls: [URL]
    ) -> [PDFDocument] {
        var allSplitPDFs: [PDFDocument] = []
        
        for url in urls {
            if let pdf = PDFDocument(url: url) {
                let rotationAngle = state.selectedPDFs.first(where: { $0.pdfURL == url })?.rotationAngle ?? 0
                
                for i in 0..<pdf.pageCount {
                    let singlePagePDF = PDFDocument()
                    
                    if let page = pdf.page(at: i) {
                        page.rotation = rotationAngle
                        singlePagePDF.insert(
                            page,
                            at: 0
                        )
                        allSplitPDFs.append(singlePagePDF)
                    }
                }
            }
        }
        
        if !allSplitPDFs.isEmpty {
            Task {
                await MainActor.run {
                    if let selectedURL = showDirectoryPanel(
                        prompt: "Save Split PDFs"
                    ) {
                        var successCount = 0
                        var failureCount = 0
                        
                        for (index, pdfDocument) in allSplitPDFs.enumerated() {
                            let fileName = "split_\(index).pdf"
                            let fileURL = selectedURL.appendingPathComponent(fileName)
                            
                            do {
                                if let data = pdfDocument.dataRepresentation() {
                                    try data.write(to: fileURL)
                                    print("Successfully saved: \(fileURL.path)")
                                    successCount += 1
                                } else {
                                    failureCount += 1
                                }
                            } catch {
                                print("Failed to save: \(fileURL.path). Error: \(error.localizedDescription)")
                                failureCount += 1
                            }
                        }
                        
                        if failureCount == 0 {
                            self.send(.showAlert(
                                message: "Successfully saved \(successCount) PDF files",
                                success: true
                            ))
                        } else if successCount > 0 {
                            self.send(.showAlert(
                                message: "Partially successful: Saved \(successCount) files, failed to save \(failureCount) files",
                                success: true
                            ))
                        } else {
                            self.send(.showAlert(
                                message: "Failed to save any PDF files",
                                success: false
                            ))
                        }
                    }
                }
            }
        }
        
        return allSplitPDFs
    }
    
    func deletePDF(
        with id: UUID
    ) {
        state.selectedPDFs.removeAll { $0.id == id }
    }
    
    private func selectImages() {
        let urls = openFilePanel(
            contentTypes: [.png, .jpeg, .tiff, .heic, .bmp, .gif],
            multipleSelection: true
        )
        
        for url in urls {
            if !state.imageURLs.contains(url),
               let image = NSImage(contentsOf: url)
            {
                state.selectedImages.append(image)
                state.imageURLs.append(url)
            }
        }
    }
    
    private func convertImagesToPDF(
        imageUrls: [URL]
    ) {
        let pdfDocument = PDFDocument()
        
        for (index, imageUrl) in imageUrls.enumerated() {
            if let image = NSImage(contentsOf: imageUrl),
               let pdfPage = PDFPage(image: image)
            {
                pdfDocument.insert(pdfPage, at: index)
            }
        }
        
        if let saveURL = showSavePanel(
            defaultName: "ConvertedImages.pdf",
            prompt: "Save Converted PDF",
            allowedTypes: [.pdf]
        ) {
            savePDFDocument(
                pdfDocument,
                to: saveURL,
                successMessage: "Successfully converted images to PDF file"
            )
        }
    }
    
    private func deleteImage(
        at index: Int
    ) {
        guard index < state.selectedImages.count else { return }
        
        state.selectedImages.remove(at: index)
        state.imageURLs.remove(at: index)
    }
    
    private func openFilePanel(
        contentTypes: [UTType],
        multipleSelection: Bool
    ) -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = contentTypes
        panel.allowsMultipleSelection = multipleSelection
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        return panel.runModal() == .OK ? panel.urls : []
    }
    
    private func showSavePanel(
        defaultName: String,
        prompt: String,
        allowedTypes: [UTType]
    ) -> URL? {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = allowedTypes
        savePanel.nameFieldStringValue = defaultName
        savePanel.prompt = prompt
        savePanel.canCreateDirectories = true
        
        return savePanel.runModal() == .OK ? savePanel.url : nil
    }
    
    private func showDirectoryPanel(
        prompt: String
    ) -> URL? {
        let savePanel = NSOpenPanel()
        savePanel.canChooseDirectories = true
        savePanel.canChooseFiles = false
        savePanel.allowsMultipleSelection = false
        savePanel.prompt = prompt
        
        return savePanel.runModal() == .OK ? savePanel.url : nil
    }
    
    private func savePDFDocument(
        _ document: PDFDocument,
        to url: URL,
        successMessage: String
    ) {
        do {
            if let data = document.dataRepresentation() {
                try data.write(to: url)
                print("\(successMessage) at \(url.path)")
                
                send(.showAlert(
                    message: successMessage,
                    success: true
                ))
            } else {
                send(.showAlert(
                    message: "Failed to create PDF data",
                    success: false
                ))
            }
        } catch {
            print("Failed to save PDF. Error: \(error.localizedDescription)")
            
            send(.showAlert(
                message: "Failed to save PDF: \(error.localizedDescription)",
                success: false
            ))
        }
    }
}
