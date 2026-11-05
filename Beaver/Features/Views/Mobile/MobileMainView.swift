#if os(iOS)
import AsyncReactor
import BeaverCore
import PhotosUI
import QuickLook
import SwiftUI

/// Beaver on iPhone and iPad: one grid of PDFs and images in output order, inside a
/// navigation stack. Add and the actions sit in the bottom toolbar within thumb reach;
/// Select switches the grid to choosing files, as in Photos and Files.
struct MobileMainView: View {
    @EnvironmentObject private var reactor: BeaverReactor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSelecting = false
    @State private var isDropTargeted = false
    @State private var isPhotoPickerPresented = false
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var photoImport: Task<Void, Never>?
    @State private var scanRequest: ScanRequest?
    @State private var isScanPhotoPickerPresented = false
    @State private var scanPhotoSelection: [PhotosPickerItem] = []
    @State private var isCameraDeniedPresented = false

    @ActionBinding(
        BeaverReactor.self,
        keyPath: \.isFileImporterPresented,
        action: BeaverReactor.SyncAction.didChangeFileImporterPresented
    )
    private var isFileImporterPresented: Bool

    @ActionBinding(
        BeaverReactor.self,
        keyPath: \.isPagesPresented,
        action: BeaverReactor.SyncAction.didChangePagesPresented
    )
    private var isPagesPresented: Bool

    @ActionBinding(
        BeaverReactor.self,
        keyPath: \.quickLookURL,
        action: BeaverReactor.SyncAction.didChangeQuickLook
    )
    private var quickLookURL: URL?

    private var state: BeaverReactor.State { reactor.state }

    private var recognizedTextBinding: Binding<RecognizedTextSheet.Content?> {
        Binding(
            get: { reactor.state.recognizedText },
            set: { value in
                if value == nil {
                    reactor.action(.dismissRecognizedText)
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            droppableContent
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(isSelecting ? .inline : .automatic)
                .toolbar {
                    MobileWorkspaceToolbar(
                        reactor: reactor,
                        isSelecting: $isSelecting,
                        onAddPhotos: { isPhotoPickerPresented = true },
                        onAddFiles: { reactor.send(.chooseFiles) },
                        onScan: startScan,
                        onScanFromPhoto: { isScanPhotoPickerPresented = true }
                    )
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { statusBar }
                .animation(reduceMotion ? nil : .snappy, value: state.isEmpty)
                .animation(reduceMotion ? nil : .snappy, value: state.activity)
                .animation(reduceMotion ? nil : .snappy, value: state.exportAlert)
                .animation(reduceMotion ? nil : .snappy, value: photoImport != nil)
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $photoSelection,
            maxSelectionCount: nil,
            selectionBehavior: .ordered,
            matching: .images,
            preferredItemEncoding: .current
        )
        .onChange(of: photoSelection) { _, items in
            importPhotos(items)
        }
        .onChange(of: scanPhotoSelection) { _, items in
            guard !items.isEmpty else { return }
            scanPhotoSelection = []
            scanRequest = ScanRequest(source: .photos(items))
        }
        .fullScreenCover(item: $scanRequest) { request in
            ScanFlowView(request: request) { url in
                scanRequest = nil
                reactor.send(.addScan(url))
            }
        }
        .alert(DesignSystem.Scan.cameraDeniedTitle, isPresented: $isCameraDeniedPresented) {
            Button(DesignSystem.Scan.openSettings) { ScanSettings.open() }
            Button(DesignSystem.Scan.cancel, role: .cancel) {}
        } message: {
            Text(DesignSystem.Scan.cameraDeniedMessage)
        }
        .quickLookPreview($quickLookURL, in: state.items.map(\.url))
        .sheet(isPresented: $isPagesPresented) {
            if let pdf = state.pagesPDF {
                PDFPagesView(pdf: pdf)
                    .environmentObject(reactor)
            }
        }
        .removeAllConfirmation(reactor: reactor)
        .exportAlert(reactor: reactor)
        .sheet(item: recognizedTextBinding) { _ in
            RecognizedTextSheet(content: recognizedTextBinding)
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: state.fileImport?.allowedContentTypes ?? [],
            allowsMultipleSelection: state.fileImport?.allowsMultipleSelection ?? false
        ) { result in
            switch result {
            case .success(let urls):
                reactor.send(.didImportFiles(urls))
            case .failure(let error):
                reactor.send(.didFailFileImport(error.localizedDescription))
            }
        }
        .modifier(FileDialogConfirmationLabel(label: state.fileImport?.confirmationLabel))
        .focusedSceneObject(reactor)
        .onChange(of: state.isEmpty) { _, isEmpty in
            if isEmpty { isSelecting = false }
        }
        .onChange(of: isSelecting) { _, selecting in
            if !selecting { reactor.action(.deselectAll) }
        }
        .sensoryFeedback(trigger: state.exportAlert) { _, alert in
            guard let alert else { return nil }
            return alert.isSuccess ? .success : .error
        }
    }

    private var title: String {
        guard isSelecting else { return DesignSystem.Workspace.title }
        let count = state.selection.count
        return count == 0 ? DesignSystem.Mobile.selectItems : DesignSystem.Mobile.selectedTitle(count)
    }

    /// iPad takes PDFs and images dragged in from Files or another app.
    private var droppableContent: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .fileDrop(isTargeted: $isDropTargeted) { urls in
                reactor.send(.addFiles(urls))
            }
            // Its own picker, so photos picked to scan never land in the list as they are.
            .photosPicker(
                isPresented: $isScanPhotoPickerPresented,
                selection: $scanPhotoSelection,
                maxSelectionCount: nil,
                selectionBehavior: .ordered,
                matching: .images,
                preferredItemEncoding: .current
            )
            .overlay {
                if isDropTargeted && !state.isEmpty {
                    DropHighlight()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if state.isEmpty {
            MobileEmptyStateView(
                isTargeted: isDropTargeted,
                onAddPhotos: { isPhotoPickerPresented = true },
                onAddFiles: { reactor.send(.chooseFiles) },
                onScan: startScan,
                onScanFromPhoto: { isScanPhotoPickerPresented = true }
            )
        } else {
            MobileWorkspaceGrid(isSelecting: isSelecting)
        }
    }

    /// Export progress, or what to do with the new PDF.
    @ViewBuilder
    private var statusBar: some View {
        if photoImport != nil {
            ActivityBar(title: DesignSystem.Mobile.addingPhotos) {
                photoImport?.cancel()
                photoImport = nil
            }
            .transition(barTransition)
        } else if let activity = state.activity {
            ActivityBar(title: activity.title) {
                reactor.action(.cancelExport)
            }
            .transition(barTransition)
        } else if let alert = state.exportAlert, alert.isSuccess {
            ExportBanner(
                alert: alert,
                onAddToWorkspace: state.exportToAdd.map { _ in
                    { reactor.send(.addExportToWorkspace) }
                }
            ) {
                reactor.action(.didDismissAlert)
            }
            // A new export gets a new banner, with its own timer.
            .id(alert.message)
            .transition(barTransition)
        }
    }

    /// Opens the document camera, or explains how to turn the camera back on.
    private func startScan() {
        if ScanAvailability.isCameraDenied {
            isCameraDeniedPresented = true
        } else {
            scanRequest = ScanRequest(source: .camera)
        }
    }

    /// Copies the picked photos in, in the order they were picked, and adds them.
    private func importPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        photoSelection = []
        photoImport?.cancel()
        photoImport = Task {
            let result = await PhotoLibraryImporter.load(items)
            guard !Task.isCancelled else { return }
            photoImport = nil
            if !result.urls.isEmpty {
                reactor.send(.addFiles(result.urls))
            }
            if result.failedCount > 0 {
                reactor.send(.showAlert(message: DesignSystem.Mobile.photosFailed(result.failedCount), success: false))
            }
        }
    }

    private var barTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }
}
#endif
