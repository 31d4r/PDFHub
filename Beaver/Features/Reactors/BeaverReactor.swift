import BeaverCore
import AsyncReactor
import SwiftUI
import UniformTypeIdentifiers

/// The state of Beaver's single window: one ordered list of PDFs and images, a Finder-style
/// selection, and undo for every change to the list.
final class BeaverReactor: AsyncReactor {
    enum Action {
        /// Shows the file importer for PDFs and images.
        case chooseFiles
        /// Adds PDFs and images in the given order, skipping ones already listed.
        case addFiles([URL])
        /// Runs Merge, Split, Convert or Combine on `ids`, or on the targets when `ids` is nil.
        /// Merge, Convert and Combine ask where to save one PDF; Split asks for a folder.
        case perform(DocumentAction, ids: Set<UUID>? = nil)

        /// Asks before Remove All; runs immediately when the list is empty.
        case requestRemoveAll
        case confirmRemoveAll

        /// The user picked files or a folder in the importer for `state.fileImport`.
        case didImportFiles([URL])
        case didFailFileImport(String)

        case showAlert(
            message: String,
            success: Bool
        )
    }

    enum SyncAction {
        /// Replaces the PDFs in the list (images stay), e.g. for previews and tests.
        case setPDFs([PDFItem])
        case didDismissAlert
        /// Stops the running export. Nothing is saved unless writing had already begun.
        case cancelExport
        case didCancelRemoveAll
        case didChangeFileImporterPresented(Bool)

        case select(UUID, SelectionModifier)
        case selectAll
        case deselectAll
        /// Moves the keyboard focus by `offset` items; ⇧ extends the selection.
        case moveFocus(offset: Int, extending: Bool)

        /// List changes are synchronous so a click, drop or key press applies at once,
        /// and each one can be undone. All are ignored while an export runs.
        case move(id: UUID, to: Int)
        case remove(Set<UUID>)
        case rotate(id: UUID, direction: RotationDirection)
        /// Turns the selected files. Does nothing when nothing is selected.
        case rotateSelection(RotationDirection)
        /// Turns every file, whatever is selected.
        case rotateAll(RotationDirection)
        /// Turns single pages (zero-based) of one PDF on top of its file rotation.
        case rotatePages(id: UUID, pages: [Int], direction: RotationDirection)
        /// Turns every page of one PDF, from the page view.
        case rotateAllPages(id: UUID, direction: RotationDirection)
        /// Opens the page view for one PDF.
        case showPages(id: UUID)
        case didChangePagesPresented(Bool)
        /// Opens Quick Look for the focused or first selected file, or closes it.
        case toggleQuickLook
        case didChangeQuickLook(URL?)
        /// Shows the page view for a PDF, or Quick Look for an image.
        case open(id: UUID)
        case undo
        case redo
    }

    /// The modifier keys held during a click.
    enum SelectionModifier: Sendable {
        case none
        case command
        case shift
    }

    /// What a change to the list was, for "Undo …" and "Redo …" menu titles.
    enum Edit: Equatable, Sendable {
        case add
        case remove
        case removeAll
        case move
        case rotate
        case rotateAll
        case rotatePages
        case rotateAllPages

        var title: String {
            switch self {
            case .add: return DesignSystem.Commands.addEditName
            case .remove: return DesignSystem.Commands.removeEditName
            case .removeAll: return DesignSystem.Commands.removeAllEditName
            case .move: return DesignSystem.Commands.moveEditName
            case .rotate: return DesignSystem.Commands.rotateEditName
            case .rotateAll: return DesignSystem.Commands.rotateAllEditName
            case .rotatePages: return DesignSystem.Commands.rotatePagesEditName
            case .rotateAllPages: return DesignSystem.Commands.rotateAllPagesEditName
            }
        }
    }

    /// Long-running work in progress. While set, the list can't change and exports are ignored.
    enum Activity: Equatable {
        case merging
        case splitting
        case converting
        case combining

        var title: String {
            switch self {
            case .merging: return DesignSystem.Progress.merging
            case .splitting: return DesignSystem.Progress.splitting
            case .converting: return DesignSystem.Progress.converting
            case .combining: return DesignSystem.Progress.combining
            }
        }
    }

    struct State {
        var items: [WorkspaceItem] = []
        var selection = ItemSelection<UUID>()
        var exportAlert: ExportAlert?
        var activity: Activity?
        var isConfirmingRemoveAll = false
        /// What the file importer is for. Kept after dismissal so a late completion still applies.
        var fileImport: FileImportRequest?
        var isFileImporterPresented = false
        var history = UndoHistory<[WorkspaceItem], Edit>()
        /// The PDF whose page view is open.
        var pagesPDFID: UUID?
        /// The file shown in Quick Look.
        var quickLookURL: URL?

        var pdfs: [PDFItem] { items.pdfs }
        var images: [ImageItem] { items.images }
        var isEmpty: Bool { items.isEmpty }
        var hasSelection: Bool { !selection.isEmpty }

        /// What toolbar and menu actions work on: the selection, or everything when nothing is selected.
        var targets: [WorkspaceItem] { items.targets(selection: selection.ids) }

        var selectedItems: [WorkspaceItem] { items.filter { selection.contains($0.id) } }

        var isPagesPresented: Bool { pagesPDFID != nil }

        var pagesPDF: PDFItem? {
            pagesPDFID.flatMap { id in pdfs.first { $0.id == id } }
        }

        var isIdle: Bool { activity == nil && !isConfirmingRemoveAll }

        /// Whether the list can be changed from the main window right now.
        var canEdit: Bool { isIdle && pagesPDFID == nil }

        /// Whether Rotate Left/Right (the selection) and Rotate All have anything to turn.
        var canRotateSelection: Bool { canEdit && hasSelection }
        var canRotateAll: Bool { canEdit && !items.isEmpty }
        var canRemoveSelection: Bool { canEdit && hasSelection }
        var canRemoveAll: Bool { canEdit && !items.isEmpty }

        var canUndo: Bool { activity == nil && history.canUndo }
        var canRedo: Bool { activity == nil && history.canRedo }

        /// The files an action works on: `ids` when given and not empty, else the targets.
        func targets(for ids: Set<UUID>?) -> [WorkspaceItem] {
            guard let ids, !ids.isEmpty else { return targets }
            return items.filter { ids.contains($0.id) }
        }

        /// Whether `action` can run on `ids` (or the targets) right now, and if not, why.
        func availability(of action: DocumentAction, ids: Set<UUID>? = nil) -> DocumentAction.Availability {
            let isSelection = (ids?.isEmpty == false) || hasSelection
            return action.availability(for: targets(for: ids), selection: isSelection, isBusy: !canEdit)
        }

        /// Whether the workspace holds both PDFs and images, so Combine is worth showing.
        var hasBothKinds: Bool {
            items.contains { $0.kind == .pdf } && items.contains { $0.kind == .image }
        }

        /// Whether Remove All would throw away rotations the user made.
        var hasDiscardableRotations: Bool { items.contains(where: \.isRotated) }
    }

    @Published private(set) var state: State

    private let saveLocationProvider: SaveLocationProviding
    private let imageService: ImageServiceProtocol
    private let exportService: ExportServiceProtocol
    private let securityScopedAccess = SecurityScopedAccess()
    /// The running export, kept so Cancel can stop it.
    private var exportTask: Task<ExportAlert, Never>?

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
        case .chooseFiles:
            requestFileImport(.files)
        case .addFiles(let urls):
            await addFiles(urls)
        case .perform(let documentAction, let ids):
            await perform(documentAction, ids: ids)
        case .requestRemoveAll:
            guard state.canRemoveAll else { return }
            state.isConfirmingRemoveAll = true
        case .confirmRemoveAll:
            state.isConfirmingRemoveAll = false
            recording(.removeAll) { $0.items.removeAll() }
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
        case .setPDFs(let pdfs):
            state.items = pdfs.map(WorkspaceItem.pdf) + state.items.filter { $0.kind == .image }
            didChangeItems()
        case .didDismissAlert:
            state.exportAlert = nil
        case .cancelExport:
            exportTask?.cancel()
        case .didCancelRemoveAll:
            state.isConfirmingRemoveAll = false
        case .didChangeFileImporterPresented(let isPresented):
            state.isFileImporterPresented = isPresented
        case .select(let id, let modifier):
            select(id, modifier)
        case .selectAll:
            state.selection.selectAll(state.items.map(\.id))
        case .deselectAll:
            state.selection.clear()
        case .moveFocus(let offset, let extending):
            state.selection.step(by: offset, in: state.items.map(\.id), extending: extending)
        case .move(let id, let index):
            recording(.move) { $0.items.move(id: id, to: index) }
        case .remove(let ids):
            recording(.remove) { $0.items.removeAll { ids.contains($0.id) } }
        case .rotate(let id, let direction):
            recording(.rotate) { state in
                guard let index = state.items.firstIndex(where: { $0.id == id }) else { return }
                state.items[index].rotate(direction)
            }
        case .rotateSelection(let direction):
            let selected = state.selection.ids
            guard !selected.isEmpty else { return }
            recording(.rotate) { state in
                for index in state.items.indices where selected.contains(state.items[index].id) {
                    state.items[index].rotate(direction)
                }
            }
        case .rotateAll(let direction):
            recording(.rotateAll) { state in
                for index in state.items.indices {
                    state.items[index].rotate(direction)
                }
            }
        case .rotatePages(let id, let pages, let direction):
            updatePDF(id, edit: .rotatePages) { $0.rotatePages(pages, direction) }
        case .rotateAllPages(let id, let direction):
            updatePDF(id, edit: .rotateAllPages) { $0.rotationAngle = $0.rotationAngle.rotated(direction) }
        case .showPages(let id):
            guard state.activity == nil, state.pdfs.contains(where: { $0.id == id }) else { return }
            state.pagesPDFID = id
        case .didChangePagesPresented(let isPresented):
            if !isPresented { state.pagesPDFID = nil }
        case .toggleQuickLook:
            state.quickLookURL = state.quickLookURL == nil ? quickLookCandidate()?.url : nil
        case .didChangeQuickLook(let url):
            state.quickLookURL = url
        case .open(let id):
            guard let item = state.items.first(where: { $0.id == id }) else { return }
            switch item {
            case .pdf: self.action(SyncAction.showPages(id: id))
            case .image: state.quickLookURL = item.url
            }
        case .undo:
            stepHistory { history, current in history.undo(current: current) }
        case .redo:
            stepHistory { history, current in history.redo(current: current) }
        }
    }

    // MARK: - Selection

    private func select(_ id: UUID, _ modifier: SelectionModifier) {
        guard state.items.contains(id: id) else { return }
        switch modifier {
        case .none: state.selection.click(id)
        case .command: state.selection.commandClick(id)
        case .shift: state.selection.shiftClick(id, in: state.items.map(\.id))
        }
    }

    /// The focused file when it's selected, else the first selected one, else the first file.
    private func quickLookCandidate() -> WorkspaceItem? {
        if let focus = state.selection.focus, state.selection.contains(focus),
           let item = state.items.first(where: { $0.id == focus }) {
            return item
        }
        return state.selectedItems.first ?? state.items.first
    }

    // MARK: - Editing and undo

    /// Applies `change` and, if it changed the list, records the previous list for undo.
    private func recording(_ edit: Edit, _ change: (inout State) -> Void) {
        guard state.activity == nil else { return }
        let before = state.items
        change(&state)
        guard state.items != before else { return }
        state.history.record(before, label: edit)
        didChangeItems()
    }

    private func updatePDF(_ id: UUID, edit: Edit, _ change: @escaping (inout PDFItem) -> Void) {
        recording(edit) { state in
            guard let index = state.items.firstIndex(where: { $0.id == id }),
                  case .pdf(var pdf) = state.items[index]
            else { return }
            change(&pdf)
            state.items[index] = .pdf(pdf)
        }
    }

    private func stepHistory(
        _ step: (inout UndoHistory<[WorkspaceItem], Edit>, [WorkspaceItem]) -> [WorkspaceItem]?
    ) {
        guard state.activity == nil,
              let target = step(&state.history, state.items)
        else { return }
        state.items = target
        didChangeItems()
    }

    /// Keeps the selection, the page view and file access in line with the list.
    private func didChangeItems() {
        state.selection.prune(keeping: state.items.map(\.id))
        if let id = state.pagesPDFID, !state.pdfs.contains(where: { $0.id == id }) {
            state.pagesPDFID = nil
        }
        if let url = state.quickLookURL, !state.items.contains(where: { $0.url == url }) {
            state.quickLookURL = nil
        }
        releaseUnusedFileAccess()
    }

    /// Ends security-scoped access for files that are neither listed nor reachable through undo.
    private func releaseUnusedFileAccess() {
        let reachable = ([state.items] + state.history.snapshots).flatMap { $0.map(\.url) }
        securityScopedAccess.retainOnly(Set(reachable))
    }

    // MARK: - Adding files

    private func requestFileImport(_ request: FileImportRequest) {
        guard state.canEdit else { return }
        state.fileImport = request
        state.isFileImporterPresented = true
    }

    private func completeFileImport(_ urls: [URL]) async {
        guard let request = state.fileImport else { return }
        state.fileImport = nil
        state.isFileImporterPresented = false

        switch request {
        case .files:
            securityScopedAccess.begin(urls)
            await addFiles(urls)
            releaseUnusedFileAccess()
        case .splitDestination(let sources):
            guard let directory = urls.first else { return }
            await split(sources, into: directory)
        }
    }

    private func addFiles(_ urls: [URL]) async {
        guard state.activity == nil else { return }
        var seen = Set(state.items.map(\.url))
        let candidates = urls.filter { seen.insert($0).inserted }
        guard !candidates.isEmpty else { return }

        let imageURLs = DroppedFileKind.image.filter(candidates)
        let loaded = await Self.loadImages(imageURLs, using: imageService)

        // The list may have changed while images were loading.
        var current = Set(state.items.map(\.url))
        var unreadableURLs: [URL] = []
        var newItems: [WorkspaceItem] = []
        for url in candidates {
            let item: WorkspaceItem
            if DroppedFileKind.pdf.accepts(url) {
                item = .pdf(PDFItem(url: url))
            } else if let image = loaded[url], let thumbnail = image.thumbnail {
                item = .image(ImageItem(url: url, thumbnail: thumbnail, pixelSize: image.pixelSize))
            } else {
                unreadableURLs.append(url)
                continue
            }
            if current.insert(url).inserted {
                newItems.append(item)
            }
        }

        if !unreadableURLs.isEmpty {
            state.exportAlert = ExportAlert(
                message: DesignSystem.Alerts.skippedFiles(unreadableURLs),
                isSuccess: false
            )
        }

        guard !newItems.isEmpty else { return }
        recording(.add) { $0.items.append(contentsOf: newItems) }
    }

    private struct LoadedImage: Sendable {
        let thumbnail: CGImage?
        let pixelSize: CGSize?
    }

    @concurrent
    private nonisolated static func loadImages(
        _ urls: [URL],
        using imageService: any ImageServiceProtocol
    ) async -> [URL: LoadedImage] {
        Dictionary(
            urls.map { url in
                (url, LoadedImage(
                    thumbnail: imageService.thumbnail(for: url, maxPixelSize: thumbnailMaxPixelSize),
                    pixelSize: imageService.pixelSize(for: url)
                ))
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// Twice the largest card (320 pt) plus some room, so previews stay sharp on Retina.
    private nonisolated static let thumbnailMaxPixelSize = 800

    // MARK: - Export

    /// Runs `work` off the main actor with `activity` shown, then presents its result.
    private func runExport(
        _ activity: Activity,
        _ work: @escaping @Sendable () async -> ExportAlert
    ) async {
        state.activity = activity
        state.exportAlert = nil
        let task = Task { await work() }
        exportTask = task
        let alert = await task.value
        exportTask = nil
        state.activity = nil
        state.exportAlert = task.isCancelled ? nil : alert
    }

    private func perform(_ action: DocumentAction, ids: Set<UUID>?) async {
        guard state.availability(of: action, ids: ids).isAvailable else { return }
        let sources = action.sources(from: state.targets(for: ids))

        if action == .split {
            requestFileImport(.splitDestination(sources.map(\.exportSource)))
            return
        }

        guard let saveURL = saveLocationProvider.saveLocation(
            defaultName: action.defaultFileName,
            prompt: action.savePrompt
        ) else {
            return
        }

        let exportService = exportService
        switch action {
        case .merge:
            let pdfs = sources.pdfs
            await runExport(.merging) {
                await exportService.mergePDFs(urls: pdfs.map(\.url), rotations: pdfs.map(\.rotation), to: saveURL)
            }
        case .convert:
            let images = sources.images
            await runExport(.converting) {
                await exportService.convertImages(
                    urls: images.map(\.url),
                    rotations: images.map(\.rotationAngle),
                    to: saveURL
                )
            }
        case .combine:
            let exportSources = sources.map(\.exportSource)
            await runExport(.combining) {
                await exportService.combine(sources: exportSources, to: saveURL)
            }
        case .split:
            break
        }
    }

    private func split(_ sources: [ExportSource], into directory: URL) async {
        guard !sources.isEmpty, state.activity == nil else { return }

        let isScoped = directory.startAccessingSecurityScopedResource()
        defer {
            if isScoped { directory.stopAccessingSecurityScopedResource() }
        }

        let exportService = exportService
        let pdfs: [(URL, PDFRotation)] = sources.compactMap { source in
            if case .pdf(let url, let rotation) = source { return (url, rotation) }
            return nil
        }

        await runExport(.splitting) {
            if pdfs.count == sources.count {
                return await exportService.splitPDFs(urls: pdfs.map(\.0), rotations: pdfs.map(\.1), into: directory)
            }
            return await exportService.split(sources: sources, into: directory)
        }
    }
}
