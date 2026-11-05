#if os(iOS)
import BeaverCore
import PhotosUI
import SwiftUI

/// Checks a scan before it becomes a PDF: swipe through the pages, pick a look for each,
/// fix corners, turn, reorder, delete, retake or add pages. It's a modal task, so the only ways
/// out are Cancel and Save, never a back button; the name opens a menu with Rename.
struct ScanReviewView: View {
    let isLoadingPhotos: Bool
    let onClose: () -> Void

    @EnvironmentObject private var reactor: ScanReactor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var camera: CameraPurpose?
    @State private var croppingPage: ScanPage?
    @State private var isPagesPresented = false
    @State private var isDiscardPresented = false
    @State private var isCameraDeniedPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var isLoadingMorePhotos = false
    @State private var isRenamePresented = false
    @State private var draftName = ""

    private var state: ScanReactor.State { reactor.state }

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background.secondary)
                // A plain title, not an editable one: the editor toolbar role that renames in
                // place also adds a back button, which here would leave without asking.
                .navigationTitle(state.name)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden()
                .toolbar { toolbar }
                .overlay { progress }
                .animation(reduceMotion ? nil : .snappy, value: state.pages.map(\.id))
        }
        .interactiveDismissDisabled(state.needsDiscardConfirmation)
        .alert(DesignSystem.Scan.renameTitle, isPresented: $isRenamePresented) {
            TextField(DesignSystem.Scan.namePlaceholder, text: $draftName)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
            Button(DesignSystem.Scan.cancel, role: .cancel) {}
            Button(DesignSystem.Scan.renameConfirm) {
                reactor.action(.rename(draftName))
            }
        } message: {
            Text(DesignSystem.Scan.renameMessage)
        }
        .confirmationDialog(
            DesignSystem.Scan.discardTitle,
            isPresented: $isDiscardPresented,
            titleVisibility: .visible
        ) {
            Button(DesignSystem.Scan.discard, role: .destructive) {
                reactor.action(.discard)
                onClose()
            }
            Button(DesignSystem.Scan.keepEditing, role: .cancel) {}
        } message: {
            Text(DesignSystem.Scan.discardMessage(state.pages.count))
        }
        .alert(
            DesignSystem.Scan.cameraDeniedTitle,
            isPresented: $isCameraDeniedPresented
        ) {
            Button(DesignSystem.Scan.openSettings) { ScanSettings.open() }
            Button(DesignSystem.Scan.cancel, role: .cancel) {}
        } message: {
            Text(DesignSystem.Scan.cameraDeniedMessage)
        }
        .alert(
            state.errorMessage ?? "",
            isPresented: Binding(
                get: { state.isErrorPresented },
                set: { if !$0 { reactor.action(.didDismissError) } }
            )
        ) {
            Button(DesignSystem.Scan.done, role: .cancel) {}
        }
        .fullScreenCover(item: $camera) { purpose in
            DocumentCameraView { images in
                camera = nil
                add(images, for: purpose)
            } onCancel: {
                camera = nil
            }
            .ignoresSafeArea()
        }
        .sheet(item: $croppingPage) { page in
            ScanCropView(page: page) { quad in
                reactor.action(.setQuad(quad, id: page.id))
            }
        }
        .sheet(isPresented: $isPagesPresented) {
            ScanPagesSheet()
                .environmentObject(reactor)
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
            guard !items.isEmpty else { return }
            photoSelection = []
            Task { await addPhotos(items) }
        }
        .sensoryFeedback(.selection, trigger: state.currentPage?.filter)
        .sensoryFeedback(.impact(weight: .light), trigger: state.currentPage?.rotation)
        .sensoryFeedback(.success, trigger: state.savedURL) { _, url in url != nil }
        .sensoryFeedback(.error, trigger: state.errorMessage) { _, message in message != nil }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if state.pages.isEmpty {
            if !isBusy {
                ContentUnavailableView {
                    Label(DesignSystem.Scan.noPagesTitle, systemImage: DesignSystem.Scan.Icons.scan)
                } description: {
                    Text(DesignSystem.Scan.noPagesMessage)
                } actions: {
                    addPagesButtons
                        .buttonStyle(.bordered)
                }
            }
        } else {
            VStack(spacing: DesignSystem.Spacing.medium) {
                pager
                if let page = state.currentPage, let index = state.currentIndex {
                    Text(DesignSystem.Scan.pageCounter(index + 1, of: state.pages.count))
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    ScanFilterStrip(page: page, isEnabled: state.canEdit) { filter in
                        reactor.action(.setFilter(filter))
                    }
                    applyToAllButton
                }
            }
            .padding(.bottom, DesignSystem.Spacing.small)
        }
    }

    private var pager: some View {
        TabView(selection: currentPageBinding) {
            ForEach(Array(state.pages.enumerated()), id: \.element.id) { index, page in
                ScanPageImage(page: page, maxPixelSize: DesignSystem.Scan.pagePreviewPixels)
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
                    .padding(DesignSystem.Spacing.large)
                    .tag(Optional(page.id))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(DesignSystem.Scan.pageTitle(index + 1))
                    .accessibilityValue(DesignSystem.Scan.filterName(page.filter))
                    .accessibilityAddTraits(.isImage)
                    .contextMenu { pageMenu(for: page) }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    @ViewBuilder
    private func pageMenu(for page: ScanPage) -> some View {
        Button {
            croppingPage = page
        } label: {
            Label(DesignSystem.Scan.crop, systemImage: DesignSystem.Scan.Icons.crop)
        }
        Button {
            reactor.action(.rotate(id: page.id, direction: .right))
        } label: {
            Label(DesignSystem.Scan.rotate, systemImage: DesignSystem.Scan.Icons.rotate)
        }
        Divider()
        Button(role: .destructive) {
            reactor.action(.delete([page.id]))
        } label: {
            Label(DesignSystem.Scan.deletePage, systemImage: DesignSystem.Scan.Icons.delete)
        }
    }

    @ViewBuilder
    private var applyToAllButton: some View {
        if state.pages.count > 1 {
            Button {
                reactor.action(.applyFilterToAll)
            } label: {
                Label(DesignSystem.Scan.applyToAll, systemImage: DesignSystem.Scan.Icons.applyToAll)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!state.canApplyFilterToAll)
            .accessibilityHint(DesignSystem.Scan.applyToAllHelp)
        }
    }

    @ViewBuilder
    private var progress: some View {
        if isBusy {
            ProgressView {
                Text(state.activity == .saving ? DesignSystem.Scan.saving : DesignSystem.Scan.preparing)
            }
            .padding(DesignSystem.Spacing.large)
            .background(.regularMaterial, in: .rect(cornerRadius: 16, style: .continuous))
            .transition(.opacity)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(DesignSystem.Scan.cancel) {
                if state.needsDiscardConfirmation {
                    isDiscardPresented = true
                } else {
                    reactor.action(.discard)
                    onClose()
                }
            }
            .disabled(state.activity == .saving)
        }
        ToolbarItem(placement: .principal) {
            titleMenu
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(DesignSystem.Scan.save) {
                reactor.send(.save)
            }
            .fontWeight(.semibold)
            .disabled(!state.canSave || isBusy)
            .accessibilityHint(DesignSystem.Scan.saveHelp)
        }
        ToolbarItemGroup(placement: .bottomBar) {
            let page = state.currentPage
            let canChangePage = page != nil && state.canEdit && !isBusy
            Button {
                croppingPage = page
            } label: {
                Label(DesignSystem.Scan.crop, systemImage: DesignSystem.Scan.Icons.crop)
            }
            .disabled(!canChangePage)
            .accessibilityHint(DesignSystem.Scan.cropHelp)
            Spacer()
            Button {
                if let page { reactor.action(.rotate(id: page.id, direction: .right)) }
            } label: {
                Label(DesignSystem.Scan.rotate, systemImage: DesignSystem.Scan.Icons.rotate)
            }
            .disabled(!canChangePage)
            .accessibilityHint(DesignSystem.Scan.rotateHelp)
            Spacer()
            Button {
                isPagesPresented = true
            } label: {
                Label(DesignSystem.Scan.pages, systemImage: DesignSystem.Scan.Icons.pages)
            }
            .disabled(state.pages.isEmpty || !state.canEdit || isBusy)
            .accessibilityHint(DesignSystem.Scan.pagesHelp)
            Spacer()
            addMenu
            Spacer()
            Button(role: .destructive) {
                if let page { reactor.action(.delete([page.id])) }
            } label: {
                Label(DesignSystem.Scan.deletePage, systemImage: DesignSystem.Scan.Icons.delete)
            }
            .disabled(!canChangePage)
        }
    }

    /// The name, shrunk a little and then cut in the middle so the date at the end stays
    /// visible. The whole name is in the menu, in the rename field and in what VoiceOver reads.
    private var titleMenu: some View {
        Menu {
            Section(state.name) {
                Button {
                    draftName = state.name
                    isRenamePresented = true
                } label: {
                    Label(DesignSystem.Scan.rename, systemImage: DesignSystem.Scan.Icons.rename)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(state.name)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .minimumScaleFactor(0.8)
                Image(systemName: DesignSystem.Scan.Icons.titleMenu)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.primary)
        }
        .disabled(!state.canEdit || isBusy)
        .accessibilityLabel(state.name)
        .accessibilityHint(DesignSystem.Scan.renameHelp)
        .accessibilityAddTraits(.isHeader)
    }

    private var addMenu: some View {
        Menu {
            addPagesButtons
            if let page = state.currentPage {
                Divider()
                Button {
                    startCamera(.retake(page.id))
                } label: {
                    cameraLabel(DesignSystem.Scan.retake, systemImage: DesignSystem.Scan.Icons.retake)
                }
                .disabled(!ScanAvailability.isCameraScanSupported)
            }
        } label: {
            Label(DesignSystem.Scan.addPages, systemImage: DesignSystem.Scan.Icons.addPages)
        }
        .disabled(!state.canEdit || isBusy)
    }

    /// Scan More Pages and Add from Photos. Scanning says why it's off when there's no camera.
    @ViewBuilder
    private var addPagesButtons: some View {
        Button {
            startCamera(.addPages)
        } label: {
            cameraLabel(DesignSystem.Scan.scanMorePages, systemImage: DesignSystem.Scan.Icons.scan)
        }
        .disabled(!ScanAvailability.isCameraScanSupported)
        Button {
            isPhotoPickerPresented = true
        } label: {
            Label(DesignSystem.Scan.addFromPhotos, systemImage: DesignSystem.Icons.photos)
        }
    }

    private func cameraLabel(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title)
            if let reason = ScanAvailability.unavailableReason {
                Text(reason)
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }

    // MARK: - Helpers

    private var isBusy: Bool {
        state.activity != nil || isLoadingPhotos || isLoadingMorePhotos
    }

    private var currentPageBinding: Binding<UUID?> {
        Binding(get: { state.currentPageID }, set: { reactor.action(.showPage($0)) })
    }

    private func startCamera(_ purpose: CameraPurpose) {
        if ScanAvailability.isCameraDenied {
            isCameraDeniedPresented = true
        } else {
            camera = purpose
        }
    }

    private func add(_ images: [CGImage], for purpose: CameraPurpose) {
        guard !images.isEmpty else { return }
        Task {
            switch purpose {
            case .addPages:
                await reactor.action(.addCaptures(images))
            case .retake(let id):
                await reactor.action(.retake(id: id, with: images[0]))
                if images.count > 1 {
                    await reactor.action(.addCaptures(Array(images.dropFirst())))
                }
            }
        }
    }

    private func addPhotos(_ items: [PhotosPickerItem]) async {
        isLoadingMorePhotos = true
        let result = await PhotoLibraryImporter.load(items)
        isLoadingMorePhotos = false
        await reactor.action(.addPhotos(result.urls))
        ScanPhotoCleanup.remove(result.urls)
        if result.failedCount > 0 {
            reactor.action(.showError(DesignSystem.Mobile.photosFailed(result.failedCount)))
        }
    }
}

/// Why the camera is open inside the review.
private enum CameraPurpose: Identifiable, Hashable {
    case addPages
    case retake(UUID)

    var id: Self { self }
}

/// Beaver's page in the Settings app, where the camera can be turned back on.
enum ScanSettings {
    @MainActor
    static func open() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
#endif
