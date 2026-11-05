import AsyncReactor
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

final class BeaverReactor: AsyncReactor {
    enum Action {
        case selectPDF
        case addPDFs([URL])
        case mergePDF([URL])
        case splitPDF([URL])
        case deletePDF(UUID)
        case clearPDFs

        case selectImages
        case addImages([URL])
        case convertImagesToPDF
        case deleteImage(UUID)
        case clearImages

        case goBack
        case navigate(AppScreen)

        case showAlert(
            message: String,
            success: Bool
        )
        case dismissAlert
    }

    enum SyncAction {
        case didUserSelectPDF([PDF])
        case didUserSelectImages([ImageItem])
        case didChangeScreen(AppScreen)
    }

    struct State {
        var screen: AppScreen = .menu
        var selectedPDFs: [PDF] = []
        var selectedImages: [ImageItem] = []
        var exportAlert: ExportAlert?
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
        case .addPDFs(let urls):
            addPDFs(urls)
        case .mergePDF(let urls):
            mergePDFs(urls: urls)
        case .splitPDF(let urls):
            splitPDF(urls: urls)
        case .deletePDF(let id):
            deletePDF(with: id)
        case .clearPDFs:
            clearPDFs()
        case .selectImages:
            selectImages()
        case .addImages(let urls):
            addImages(urls)
        case .convertImagesToPDF:
            convertImagesToPDF()
        case .deleteImage(let id):
            deleteImage(with: id)
        case .clearImages:
            clearImages()
        case .goBack:
            goBack()
        case .navigate(let screen):
            state.screen = screen
        case .showAlert(let message, let success):
            state.exportAlert = ExportAlert(
                message: message,
                isSuccess: success
            )
        case .dismissAlert:
            state.exportAlert = nil
        }
    }

    func action(_ action: SyncAction) {
        switch action {
        case .didUserSelectPDF(let pdfs):
            state.selectedPDFs = pdfs
        case .didUserSelectImages(let images):
            state.selectedImages = images
        case .didChangeScreen(let screen):
            state.screen = screen
        }
    }

    private func selectPDF() {
        let urls = filePanelService.openFilePanel(
            contentTypes: [.pdf],
            multipleSelection: true
        )
        addPDFs(urls)
    }

    private func addPDFs(_ urls: [URL]) {
        var seen = Set(state.selectedPDFs.map(\.pdfURL))
        let newPDFs = urls.compactMap { url -> PDF? in
            guard !seen.contains(url) else { return nil }
            seen.insert(url)
            return PDF(pdfURL: url)
        }

        guard !newPDFs.isEmpty else { return }

        state.selectedPDFs.append(contentsOf: newPDFs)
        state.screen = .pdfWorkflow
    }

    private func mergePDFs(
        urls: [URL]
    ) {
        guard !urls.isEmpty else { return }

        let rotationAngles = PDFRotationMapper.mapRotationAngles(
            urls: urls,
            from: state.selectedPDFs
        )

        let result = pdfService.mergePDFs(
            urls: urls,
            rotationAngles: rotationAngles
        )

        guard let mergedPDF = result.document else {
            send(.showAlert(
                message: DesignSystem.Alerts.message(
                    DesignSystem.Alerts.failedToMergePDFs,
                    skipped: result.skippedURLs
                ),
                success: false
            ))
            return
        }

        saveMergedPDF(mergedPDF, skippedURLs: result.skippedURLs)
    }

    private func saveMergedPDF(_ mergedPDF: PDFDocument, skippedURLs: [URL]) {
        guard let saveURL = filePanelService.showSavePanel(
            defaultName: DesignSystem.FileNames.mergedPDF,
            prompt: DesignSystem.FileNames.saveMergedPDFPrompt,
            allowedTypes: [.pdf]
        ) else {
            return
        }

        do {
            try pdfFileWriterService.savePDFDocument(mergedPDF, to: saveURL)
            send(.showAlert(
                message: DesignSystem.Alerts.message(
                    DesignSystem.Alerts.mergedPDFSaved(fileName: saveURL.lastPathComponent),
                    skipped: skippedURLs
                ),
                success: true
            ))
        } catch {
            send(.showAlert(
                message: DesignSystem.Alerts.failedToSaveMergedPDF(
                    error.localizedDescription
                ),
                success: false
            ))
        }
    }

    private func splitPDF(
        urls: [URL]
    ) {
        guard !urls.isEmpty else { return }

        let rotationAngles = PDFRotationMapper.mapRotationAngles(
            urls: urls,
            from: state.selectedPDFs
        )

        let result = pdfService.splitPDF(
            urls: urls,
            rotationAngles: rotationAngles
        )

        guard !result.pages.isEmpty else {
            send(.showAlert(
                message: DesignSystem.Alerts.message(
                    DesignSystem.Alerts.noPagesFoundToSplit,
                    skipped: result.skippedURLs
                ),
                success: false
            ))
            return
        }

        saveSplitPDFs(result.pages, skippedURLs: result.skippedURLs)
    }

    private func saveSplitPDFs(_ splitPDFs: [SplitPage], skippedURLs: [URL]) {
        guard let selectedURL = filePanelService.showDirectoryPanel(
            prompt: DesignSystem.FileNames.saveSplitPDFsPrompt
        ) else {
            return
        }

        let result = pdfFileWriterService.savePDFDocuments(
            splitPDFs,
            to: selectedURL
        )

        send(.showAlert(
            message: DesignSystem.Alerts.message(
                DesignSystem.Alerts.message(for: result),
                skipped: skippedURLs
            ),
            success: !result.isCompleteFailure
        ))
    }

    private func deletePDF(
        with id: UUID
    ) {
        state.selectedPDFs.removeAll { $0.id == id }
        if state.selectedPDFs.isEmpty {
            state.screen = .menu
        }
    }

    private func clearPDFs() {
        state.selectedPDFs.removeAll()
        state.screen = .menu
    }

    private func selectImages() {
        let urls = filePanelService.openFilePanel(
            contentTypes: SupportedImageType.allUTTypes,
            multipleSelection: true
        )
        addImages(urls)
    }

    private func addImages(_ urls: [URL]) {
        var seen = Set(state.selectedImages.map(\.url))
        var unreadableURLs: [URL] = []
        let newItems = urls.compactMap { url -> ImageItem? in
            guard !seen.contains(url) else { return nil }
            guard let image = imageService.loadImage(from: url) else {
                unreadableURLs.append(url)
                return nil
            }
            seen.insert(url)
            return ImageItem(url: url, image: image)
        }

        if !unreadableURLs.isEmpty {
            send(.showAlert(
                message: DesignSystem.Alerts.skippedFiles(unreadableURLs),
                success: false
            ))
        }

        guard !newItems.isEmpty else { return }

        state.selectedImages.append(contentsOf: newItems)
        state.screen = .imageWorkflow
    }

    private func convertImagesToPDF() {
        let imageUrls = state.selectedImages.map(\.url)

        guard !imageUrls.isEmpty else {
            send(.showAlert(
                message: DesignSystem.Alerts.noImagesSelected,
                success: false
            ))
            return
        }

        let result = imageService.convertImagesToPDF(imageUrls: imageUrls)

        guard let pdfDocument = result.document else {
            send(.showAlert(
                message: DesignSystem.Alerts.message(
                    DesignSystem.Alerts.failedToConvertImages,
                    skipped: result.skippedURLs
                ),
                success: false
            ))
            return
        }

        saveConvertedPDF(pdfDocument, skippedURLs: result.skippedURLs)
    }

    private func saveConvertedPDF(_ pdfDocument: PDFDocument, skippedURLs: [URL]) {
        guard let saveURL = filePanelService.showSavePanel(
            defaultName: DesignSystem.FileNames.convertedImagesPDF,
            prompt: DesignSystem.FileNames.saveConvertedPDFPrompt,
            allowedTypes: [.pdf]
        ) else {
            return
        }

        do {
            try pdfFileWriterService.savePDFDocument(pdfDocument, to: saveURL)
            send(.showAlert(
                message: DesignSystem.Alerts.message(
                    DesignSystem.Alerts.convertedImagesSuccess,
                    skipped: skippedURLs
                ),
                success: true
            ))
        } catch {
            send(.showAlert(
                message: DesignSystem.Alerts.failedToSaveConvertedPDF(
                    error.localizedDescription
                ),
                success: false
            ))
        }
    }

    private func deleteImage(
        with id: UUID
    ) {
        state.selectedImages.removeAll { $0.id == id }
        if state.selectedImages.isEmpty {
            state.screen = .menu
        }
    }

    private func clearImages() {
        state.selectedImages.removeAll()
        state.screen = .menu
    }

    private func goBack() {
        switch state.screen {
        case .pdfWorkflow:
            clearPDFs()
        case .imageWorkflow:
            clearImages()
        case .menu:
            break
        }
    }
}
