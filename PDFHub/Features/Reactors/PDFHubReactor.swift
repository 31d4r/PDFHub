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
        case clearPDFs
        
        case selectImages
        case convertImagesToPDF([URL])
        case deleteImage(Int)
        case clearImages
        
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
    
    private let filePanelService: FilePanelServiceProtocol
    private let pdfService: PDFServiceProtocol
    private let imageService: ImageServiceProtocol
    private let pdfFileWriterService: PDFFileWriterServiceProtocol
    
    init(
        filePanelService: FilePanelServiceProtocol = FilePanelService(),
        pdfService: PDFServiceProtocol = PDFService(),
        imageService: ImageServiceProtocol = ImageService(),
        pdfFileWriterService: PDFFileWriterServiceProtocol = PDFFileWriterService()
    ) {
        self.state = State()
        self.filePanelService = filePanelService
        self.pdfService = pdfService
        self.imageService = imageService
        self.pdfFileWriterService = pdfFileWriterService
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
        case .clearPDFs:
            clearPDFs()
        case .selectImages:
            selectImages()
        case .convertImagesToPDF(let urls):
            convertImagesToPDF(imageUrls: urls)
        case .deleteImage(let index):
            deleteImage(at: index)
        case .clearImages:
            clearImages()
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
        let urls = filePanelService.openFilePanel(
            contentTypes: [.pdf],
            multipleSelection: true
        )
        
        let newPDFs = urls
            .filter { url in
                !state.selectedPDFs.contains(where: { $0.pdfURL == url })
            }
            .map { url in
                PDF(pdfURL: url, rotationAngle: 0)
            }
        
        state.selectedPDFs.append(contentsOf: newPDFs)
    }
    
    func mergePDFs(
        urls: [URL]
    ) -> PDFDocument? {
        guard !urls.isEmpty else { return nil }
        
        let rotationAngles = PDFRotationMapper.mapRotationAngles(
            urls: urls,
            from: state.selectedPDFs
        )
        
        guard let mergedPDF = pdfService.mergePDFs(urls: urls, rotationAngles: rotationAngles) else {
            send(.showAlert(
                message: "Failed to merge PDFs",
                success: false
            ))
            return nil
        }
        
        saveMergedPDF(mergedPDF)
        
        return mergedPDF
    }
    
    private func saveMergedPDF(_ mergedPDF: PDFDocument) {
        guard let saveURL = filePanelService.showSavePanel(
            defaultName: "merged.pdf",
            prompt: "Save Merged PDF",
            allowedTypes: [.pdf]
        ) else {
            return
        }
        
        do {
            try pdfFileWriterService.savePDFDocument(mergedPDF, to: saveURL)
            send(.showAlert(
                message: "Merged PDF successfully saved at \(saveURL.lastPathComponent)",
                success: true
            ))
        } catch {
            send(.showAlert(
                message: "Failed to save merged PDF: \(error.localizedDescription)",
                success: false
            ))
        }
    }
    
    func splitPDF(
        urls: [URL]
    ) -> [PDFDocument] {
        guard !urls.isEmpty else { return [] }
        
        let rotationAngles = PDFRotationMapper.mapRotationAngles(
            urls: urls,
            from: state.selectedPDFs
        )
        
        let allSplitPDFs = pdfService.splitPDF(urls: urls, rotationAngles: rotationAngles)
        
        guard !allSplitPDFs.isEmpty else {
            send(.showAlert(
                message: "No pages found to split",
                success: false
            ))
            return []
        }
        
        saveSplitPDFs(allSplitPDFs)
        
        return allSplitPDFs
    }
    
    private func saveSplitPDFs(_ splitPDFs: [PDFDocument]) {
        Task {
            await MainActor.run {
                guard let selectedURL = filePanelService.showDirectoryPanel(
                    prompt: "Save Split PDFs"
                ) else {
                    return
                }
                
                let result = pdfFileWriterService.savePDFDocuments(
                    splitPDFs,
                    to: selectedURL,
                    fileNamePrefix: "split"
                )
                
                send(.showAlert(
                    message: result.message,
                    success: !result.isCompleteFailure
                ))
            }
        }
    }
    
    func deletePDF(
        with id: UUID
    ) {
        state.selectedPDFs.removeAll { $0.id == id }
    }
    
    private func clearPDFs() {
        state.selectedPDFs.removeAll()
        state.mergedPDF = nil
        state.splitPDFs.removeAll()
    }
    
    private func selectImages() {
        let urls = filePanelService.openFilePanel(
            contentTypes: [.png, .jpeg, .tiff, .heic, .bmp, .gif],
            multipleSelection: true
        )
        
        let newImages = urls
            .filter { !state.imageURLs.contains($0) }
            .compactMap { url -> (NSImage, URL)? in
                guard let image = imageService.loadImage(from: url) else {
                    return nil
                }
                return (image, url)
            }
        
        for (image, url) in newImages {
            state.selectedImages.append(image)
            state.imageURLs.append(url)
        }
    }
    
    private func convertImagesToPDF(
        imageUrls: [URL]
    ) {
        guard !imageUrls.isEmpty else {
            send(.showAlert(
                message: "No images selected",
                success: false
            ))
            return
        }
        
        guard let pdfDocument = imageService.convertImagesToPDF(imageUrls: imageUrls) else {
            send(.showAlert(
                message: "Failed to convert images to PDF",
                success: false
            ))
            return
        }
        
        saveConvertedPDF(pdfDocument)
    }
    
    private func saveConvertedPDF(_ pdfDocument: PDFDocument) {
        guard let saveURL = filePanelService.showSavePanel(
            defaultName: "ConvertedImages.pdf",
            prompt: "Save Converted PDF",
            allowedTypes: [.pdf]
        ) else {
            return
        }
        
        do {
            try pdfFileWriterService.savePDFDocument(pdfDocument, to: saveURL)
            send(.showAlert(
                message: "Successfully converted images to PDF file",
                success: true
            ))
        } catch {
            send(.showAlert(
                message: "Failed to save converted PDF: \(error.localizedDescription)",
                success: false
            ))
        }
    }
    
    private func deleteImage(
        at index: Int
    ) {
        guard index < state.selectedImages.count else { return }
        
        state.selectedImages.remove(at: index)
        state.imageURLs.remove(at: index)
    }
    
    private func clearImages() {
        state.selectedImages.removeAll()
        state.imageURLs.removeAll()
    }
    
}
