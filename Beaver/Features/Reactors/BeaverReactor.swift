import BeaverCore
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
        /// Carries the request shown in the dialog, because dismissing the dialog clears `pendingDiscard` first.
        case confirmDiscard(DiscardRequest)

        /// The user picked files or a folder in the importer for `state.fileImport`.
        case didImportFiles([URL])
        case didFailFileImport(String)

        case showAlert(
            message: String,
            success: Bool
        )
    }

    enum SyncAction {
        case didUserSelectPDF([PDFItem])
        case didUserSelectImages([ImageItem])
        case didChangeScreen(AppScreen)
        case didDismissAlert
        case didCancelDiscard
        case didChangeFileImporterPresented(Bool)
        /// Moves a card to `index`. Synchronous so a drop or menu choice applies at once.
        case movePDF(id: UUID, to: Int)
        case moveImage(id: UUID, to: Int)
        /// Rotations are synchronous and carry their target, so a tap applies at once and
        /// each one can be undone. All are ignored while an export runs.
        case rotatePDF(id: UUID, direction: RotationDirection)
        case rotateImage(id: UUID, direction: RotationDirection)
        /// Turns every file on the current screen.
        case rotateAll(RotationDirection)
        case undo
        case redo
    }

    /// What a rotation change was, for "Undo …" and "Redo …" menu titles.
    enum RotationEdit: Equatable, Sendable {
        case rotate
        case rotateAll

        var title: String {
            switch self {
            case .rotate: return DesignSystem.Commands.rotateEditName
            case .rotateAll: return DesignSystem.Commands.rotateAllEditName
            }
        }
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
        var selectedPDFs: [PDFItem] = []
        var selectedImages: [ImageItem] = []
        var exportAlert: ExportAlert?
        var activity: Activity?
        var pendingDiscard: DiscardRequest?
        /// What the file importer is for. Kept after dismissal so a late completion still applies.
        var fileImport: FileImportRequest?
        var isFileImporterPresented = false
        var rotationHistory = UndoHistory<RotationSnapshot, RotationEdit>()

        var rotationSnapshot: RotationSnapshot {
            RotationSnapshot(pdfs: selectedPDFs, images: selectedImages)
        }

        /// Whether Rotate All has anything to turn right now.
        var canRotateAll: Bool {
            guard activity == nil else { return false }
            switch screen {
            case .pdfWorkflow: return !selectedPDFs.isEmpty
            case .imageWorkflow: return !selectedImages.isEmpty
            case .menu: return false
            }
        }

        var canUndoRotation: Bool { activity == nil && rotationHistory.canUndo }
        var canRedoRotation: Bool { activity == nil && rotationHistory.canRedo }

        /// Files on the current screen that a discard would remove.
        var discardableCount: Int {
            switch screen {
            case .pdfWorkflow: return selectedPDFs.count
            case .imageWorkflow: return selectedImages.count
            case .menu: return 0
            }
        }

        /// Whether a discard would throw away rotations the user made on the current screen.
        var hasDiscardableRotations: Bool {
            switch screen {
            case .pdfWorkflow: return selectedPDFs.contains { $0.rotationAngle != .zero }
            case .imageWorkflow: return selectedImages.contains { $0.rotationAngle != .zero }
            case .menu: return false
            }
        }
    }

    @Published private(set) var state: State

    private let saveLocationProvider: SaveLocationProviding
    private let imageService: ImageServiceProtocol
    private let exportService: ExportServiceProtocol
    private let securityScopedAccess = SecurityScopedAccess()

    init(
        saveLocationProvider: SaveLocationProviding = SavePanelService(),
        imageService: ImageServiceProtocol = ImageService(),
        exportService: ExportServiceProtocol = ExportService()
    ) {
        self.state = State()
        self.saveLocationProvider = saveLocationProvider
        self.imageService = imageService
        self.exportService = exportService
    }

    func action(_ action: Action) async {
        switch action {
        case .selectPDF:
            requestFileImport(.pdfs)
        case .addPDFs(let urls):
            addPDFs(urls)
        case .mergePDF(let urls):
            await mergePDFs(urls: urls)
        case .splitPDF(let urls):
            requestSplitDestination(for: urls)
        case .deletePDF(let id):
            deletePDF(with: id)
        case .clearPDFs:
            clearPDFs()
        case .selectImages:
            requestFileImport(.images)
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
        case .confirmDiscard(let request):
            confirmDiscard(request)
        case .didImportFiles(let urls):
            await completeFileImport(urls)
        case .didFailFileImport(let message):
            state.fileImport = nil
            state.isFileImporterPresented = false
            state.exportAlert = ExportAlert(message: message, isSuccess: false)
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
        case .didChangeFileImporterPresented(let isPresented):
            state.isFileImporterPresented = isPresented
        case .movePDF(let id, let index):
            guard state.activity == nil else { return }
            state.selectedPDFs.move(id: id, to: index)
        case .moveImage(let id, let index):
            guard state.activity == nil else { return }
            state.selectedImages.move(id: id, to: index)
        case .rotatePDF(let id, let direction):
            recordingRotation(.rotate) { state in
                guard let index = state.selectedPDFs.firstIndex(where: { $0.id == id }) else { return }
                state.selectedPDFs[index].rotationAngle = state.selectedPDFs[index].rotationAngle.rotated(direction)
            }
        case .rotateImage(let id, let direction):
            recordingRotation(.rotate) { state in
                guard let index = state.selectedImages.firstIndex(where: { $0.id == id }) else { return }
                state.selectedImages[index].rotate(direction)
            }
        case .rotateAll(let direction):
            rotateAll(direction)
        case .undo:
            stepRotationHistory { history, current in history.undo(current: current) }
        case .redo:
            stepRotationHistory { history, current in history.redo(current: current) }
        }
    }

    /// Applies `change` and, if it turned anything, records the previous rotations for undo.
    private func recordingRotation(_ edit: RotationEdit, _ change: (inout State) -> Void) {
        guard state.activity == nil else { return }
        let before = state.rotationSnapshot
        change(&state)
        if state.rotationSnapshot != before {
            state.rotationHistory.record(before, label: edit)
        }
    }

    private func rotateAll(_ direction: RotationDirection) {
        recordingRotation(.rotateAll) { state in
            switch state.screen {
            case .pdfWorkflow:
                for index in state.selectedPDFs.indices {
                    state.selectedPDFs[index].rotationAngle = state.selectedPDFs[index].rotationAngle.rotated(direction)
                }
            case .imageWorkflow:
                for index in state.selectedImages.indices {
                    state.selectedImages[index].rotate(direction)
                }
            case .menu:
                break
            }
        }
    }

    /// Undoes or redoes one step, skipping steps that no longer change anything
    /// (for example, a rotation of a card that has since been removed).
    private func stepRotationHistory(
        _ step: (inout UndoHistory<RotationSnapshot, RotationEdit>, RotationSnapshot) -> RotationSnapshot?
    ) {
        guard state.activity == nil else { return }
        while true {
            let current = state.rotationSnapshot
            guard let target = step(&state.rotationHistory, current) else { return }
            target.restore(&state.selectedPDFs)
            target.restore(&state.selectedImages)
            if state.rotationSnapshot != current { return }
        }
    }

    private func requestFileImport(_ request: FileImportRequest) {
        guard state.activity == nil else { return }
        state.fileImport = request
        state.isFileImporterPresented = true
    }

    private func requestSplitDestination(for urls: [URL]) {
        guard !urls.isEmpty else { return }
        requestFileImport(.splitDestination(urls))
    }

    private func completeFileImport(_ urls: [URL]) async {
        guard let request = state.fileImport else { return }
        state.fileImport = nil
        state.isFileImporterPresented = false

        switch request {
        case .pdfs:
            securityScopedAccess.begin(urls)
            addPDFs(urls)
            releaseUnusedFileAccess()
        case .images:
            securityScopedAccess.begin(urls)
            await addImages(urls)
            releaseUnusedFileAccess()
        case .splitDestination(let pdfURLs):
            guard let directory = urls.first else { return }
            await splitPDF(urls: pdfURLs, into: directory)
        }
    }

    /// Ends security-scoped access for files that are no longer listed.
    private func releaseUnusedFileAccess() {
        let listed = Set(state.selectedPDFs.map(\.url)).union(state.selectedImages.map(\.url))
        securityScopedAccess.retainOnly(listed)
    }

    private func addPDFs(_ urls: [URL]) {
        guard state.activity == nil else { return }
        var seen = Set(state.selectedPDFs.map(\.url))
        let newPDFs = urls.compactMap { url -> PDFItem? in
            guard !seen.contains(url) else { return nil }
            seen.insert(url)
            return PDFItem(url: url)
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

        guard let saveURL = saveLocationProvider.saveLocation(
            defaultName: DesignSystem.FileNames.mergedPDF,
            prompt: DesignSystem.FileNames.saveMergedPDFPrompt
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

    private func splitPDF(urls: [URL], into directory: URL) async {
        guard !urls.isEmpty, state.activity == nil else { return }

        let isScoped = directory.startAccessingSecurityScopedResource()
        defer {
            if isScoped { directory.stopAccessingSecurityScopedResource() }
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
        releaseUnusedFileAccess()
        if state.selectedPDFs.isEmpty {
            state.rotationHistory.removeAll()
            state.screen = .menu
        }
    }

    private func clearPDFs() {
        state.selectedPDFs.removeAll()
        state.rotationHistory.removeAll()
        releaseUnusedFileAccess()
        state.screen = .menu
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
        let rotations = state.selectedImages.map(\.rotationAngle)

        guard !imageUrls.isEmpty else {
            state.exportAlert = ExportAlert(
                message: DesignSystem.Alerts.noImagesSelected,
                isSuccess: false
            )
            return
        }

        guard let saveURL = saveLocationProvider.saveLocation(
            defaultName: DesignSystem.FileNames.convertedImagesPDF,
            prompt: DesignSystem.FileNames.saveConvertedPDFPrompt
        ) else {
            return
        }

        let exportService = exportService

        await runExport(.converting) {
            await exportService.convertImages(urls: imageUrls, rotations: rotations, to: saveURL)
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
        releaseUnusedFileAccess()
        if state.selectedImages.isEmpty {
            state.rotationHistory.removeAll()
            state.screen = .menu
        }
    }

    private func clearImages() {
        state.selectedImages.removeAll()
        state.rotationHistory.removeAll()
        releaseUnusedFileAccess()
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

    private func confirmDiscard(_ request: DiscardRequest) {
        state.pendingDiscard = nil
        guard state.activity == nil, state.screen != .menu else { return }
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
