import AsyncReactor
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

        /// Asks before discarding the current list; runs immediately when there is nothing to lose.
        case requestDiscard(DiscardRequest)
        case confirmDiscard

        case showAlert(
            message: String,
            success: Bool
        )
    }

    enum SyncAction {
        case didUserSelectPDF([PDF])
        case didUserSelectImages([ImageItem])
        case didChangeScreen(AppScreen)
        case didDismissAlert
        case didCancelDiscard
    }

    /// Something that would throw away the files the user has added.
    enum DiscardRequest: Equatable {
        case goBack
        case clearAll
    }

    /// Long-running work in progress. While set, exports are ignored and the UI is disabled.
    enum Activity: Equatable {
        case merging
        case splitting
        case converting

        var title: String {
            switch self {
            case .merging: return DesignSystem.Progress.merging
            case .splitting: return DesignSystem.Progress.splitting
            case .converting: return DesignSystem.Progress.converting
            }
        }
    }

    struct State {
        var screen: AppScreen = .menu
        var selectedPDFs: [PDF] = []
        var selectedImages: [ImageItem] = []
        var exportAlert: ExportAlert?
        var activity: Activity?
        var pendingDiscard: DiscardRequest?

        /// Files on the current screen that a discard would remove.
        var discardableCount: Int {
            switch screen {
            case .pdfWorkflow: return selectedPDFs.count
            case .imageWorkflow: return selectedImages.count
            case .menu: return 0
            }
        }
    }

    @Published private(set) var state: State

    private let filePanelService: FilePanelServiceProtocol
    private let imageService: ImageServiceProtocol
    private let exportService: ExportServiceProtocol

    init(
        filePanelService: FilePanelServiceProtocol = FilePanelService(),
        imageService: ImageServiceProtocol = ImageService(),
        exportService: ExportServiceProtocol = ExportService()
    ) {
        self.state = State()
        self.filePanelService = filePanelService
        self.imageService = imageService
        self.exportService = exportService
    }

    func action(_ action: Action) async {
        switch action {
        case .selectPDF:
            selectPDF()
        case .addPDFs(let urls):
            addPDFs(urls)
        case .mergePDF(let urls):
            await mergePDFs(urls: urls)
        case .splitPDF(let urls):
            await splitPDF(urls: urls)
        case .deletePDF(let id):
            deletePDF(with: id)
        case .clearPDFs:
            clearPDFs()
        case .selectImages:
            await selectImages()
        case .addImages(let urls):
            await addImages(urls)
        case .convertImagesToPDF:
            await convertImagesToPDF()
        case .deleteImage(let id):
            deleteImage(with: id)
        case .clearImages:
            clearImages()
        case .goBack:
            goBack()
        case .navigate(let screen):
            state.screen = screen
        case .requestDiscard(let request):
            requestDiscard(request)
        case .confirmDiscard:
            confirmDiscard()
        case .showAlert(let message, let success):
            state.exportAlert = ExportAlert(
                message: message,
                isSuccess: success
            )
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
        case .didDismissAlert:
            state.exportAlert = nil
        case .didCancelDiscard:
            state.pendingDiscard = nil
        }
    }

    private func selectPDF() {
        guard state.activity == nil else { return }
        let urls = filePanelService.openFilePanel(
            contentTypes: [.pdf],
            multipleSelection: true
        )
        addPDFs(urls)
    }

    private func addPDFs(_ urls: [URL]) {
        guard state.activity == nil else { return }
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

    /// Runs `work` off the main actor with `activity` shown, then presents its result.
    /// Ignored while another export is running.
    private func runExport(
        _ activity: Activity,
        _ work: () async -> ExportAlert
    ) async {
        state.activity = activity
        let alert = await work()
        state.activity = nil
        state.exportAlert = alert
    }

    private func mergePDFs(urls: [URL]) async {
        guard !urls.isEmpty, state.activity == nil else { return }

        guard let saveURL = filePanelService.showSavePanel(
            defaultName: DesignSystem.FileNames.mergedPDF,
            prompt: DesignSystem.FileNames.saveMergedPDFPrompt,
            allowedTypes: [.pdf]
        ) else {
            return
        }

        let rotationAngles = PDFRotationMapper.mapRotationAngles(
            urls: urls,
            from: state.selectedPDFs
        )
        let exportService = exportService

        await runExport(.merging) {
            await exportService.mergePDFs(urls: urls, rotationAngles: rotationAngles, to: saveURL)
        }
    }

    private func splitPDF(urls: [URL]) async {
        guard !urls.isEmpty, state.activity == nil else { return }

        guard let directory = filePanelService.showDirectoryPanel(
            prompt: DesignSystem.FileNames.saveSplitPDFsPrompt
        ) else {
            return
        }

        let rotationAngles = PDFRotationMapper.mapRotationAngles(
            urls: urls,
            from: state.selectedPDFs
        )
        let exportService = exportService

        await runExport(.splitting) {
            await exportService.splitPDFs(urls: urls, rotationAngles: rotationAngles, into: directory)
        }
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

    private func selectImages() async {
        guard state.activity == nil else { return }
        let urls = filePanelService.openFilePanel(
            contentTypes: SupportedImageType.allUTTypes,
            multipleSelection: true
        )
        await addImages(urls)
    }

    private func addImages(_ urls: [URL]) async {
        guard state.activity == nil else { return }
        var seen = Set(state.selectedImages.map(\.url))
        let candidates = urls.filter { seen.insert($0).inserted }
        guard !candidates.isEmpty else { return }

        let loaded = await Self.loadThumbnails(for: candidates, using: imageService)

        // The list may have changed while thumbnails were loading.
        var current = Set(state.selectedImages.map(\.url))
        var unreadableURLs: [URL] = []
        let newItems = loaded.compactMap { url, thumbnail -> ImageItem? in
            guard let thumbnail else {
                unreadableURLs.append(url)
                return nil
            }
            guard current.insert(url).inserted else { return nil }
            return ImageItem(url: url, thumbnail: thumbnail)
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

    private func convertImagesToPDF() async {
        guard state.activity == nil else { return }
        let imageUrls = state.selectedImages.map(\.url)

        guard !imageUrls.isEmpty else {
            state.exportAlert = ExportAlert(
                message: DesignSystem.Alerts.noImagesSelected,
                isSuccess: false
            )
            return
        }

        guard let saveURL = filePanelService.showSavePanel(
            defaultName: DesignSystem.FileNames.convertedImagesPDF,
            prompt: DesignSystem.FileNames.saveConvertedPDFPrompt,
            allowedTypes: [.pdf]
        ) else {
            return
        }

        let exportService = exportService

        await runExport(.converting) {
            await exportService.convertImages(urls: imageUrls, to: saveURL)
        }
    }

    @concurrent
    private nonisolated static func loadThumbnails(
        for urls: [URL],
        using imageService: any ImageServiceProtocol
    ) async -> [(URL, CGImage?)] {
        urls.map { url in
            (url, imageService.thumbnail(for: url, maxPixelSize: thumbnailMaxPixelSize))
        }
    }

    /// Twice the largest on-screen preview (400 pt), so previews stay sharp on Retina.
    private nonisolated static let thumbnailMaxPixelSize = 800

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

    private func requestDiscard(_ request: DiscardRequest) {
        guard state.activity == nil, state.screen != .menu else { return }
        if state.discardableCount == 0 {
            perform(request)
        } else {
            state.pendingDiscard = request
        }
    }

    private func confirmDiscard() {
        guard let request = state.pendingDiscard else { return }
        state.pendingDiscard = nil
        perform(request)
    }

    private func perform(_ request: DiscardRequest) {
        switch request {
        case .goBack:
            goBack()
        case .clearAll:
            switch state.screen {
            case .pdfWorkflow: clearPDFs()
            case .imageWorkflow: clearImages()
            case .menu: break
            }
        }
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
