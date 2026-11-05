import AsyncReactor
import BeaverCore
import QuickLook
import SwiftUI

/// Beaver's one window. PDFs and images share a single grid, in output order, so there's no
/// mode to pick first: what Create PDF does follows from what's in the list.
struct MainView: View {
    @EnvironmentObject private var reactor: BeaverReactor
    @AppStorage(DesignSystem.Layout.thumbnailSizeKey) private var thumbnailSize = DesignSystem.Layout.defaultThumbnailSize
    @State private var isDropTargeted = false

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

    var body: some View {
        presentations(window)
            .focusedSceneObject(reactor)
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: reactor.state.fileImport?.allowedContentTypes ?? [],
                allowsMultipleSelection: reactor.state.fileImport?.allowsMultipleSelection ?? false
            ) { result in
                switch result {
                case .success(let urls):
                    reactor.send(.didImportFiles(urls))
                case .failure(let error):
                    reactor.send(.didFailFileImport(error.localizedDescription))
                }
            }
            .modifier(FileDialogConfirmationLabel(label: reactor.state.fileImport?.confirmationLabel))
    }

    /// The content with the drop target, the progress bar, the title and the toolbar.
    private var window: some View {
        droppableContent
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let activity = reactor.state.activity {
                    ActivityBar(title: activity.title)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: reactor.state.activity)
            .navigationTitle(DesignSystem.Workspace.title)
            .windowSubtitle(subtitle)
            .toolbar {
                WorkspaceToolbar(reactor: reactor, thumbnailSize: $thumbnailSize)
            }
    }

    private var droppableContent: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
            .fileDrop(isTargeted: $isDropTargeted) { urls in
                reactor.send(.addFiles(urls))
            }
            .overlay {
                if isDropTargeted && !reactor.state.isEmpty {
                    DropHighlight()
                }
            }
    }

    private func presentations(_ view: some View) -> some View {
        view
            .quickLookPreview($quickLookURL, in: reactor.state.items.map(\.url))
            .sheet(isPresented: $isPagesPresented) {
                if let pdf = reactor.state.pagesPDF {
                    PDFPagesView(pdf: pdf)
                        .environmentObject(reactor)
                }
            }
            .removeAllConfirmation(reactor: reactor)
            .exportAlert(reactor: reactor)
    }

    @ViewBuilder
    private var content: some View {
        if reactor.state.isEmpty {
            EmptyStateView(isTargeted: isDropTargeted) {
                reactor.send(.chooseFiles)
            }
        } else {
            WorkspaceGridView()
        }
    }

    /// "2 of 5 selected", "3 PDFs, 2 images", or "No files".
    private var subtitle: String {
        let state = reactor.state
        if state.isEmpty { return DesignSystem.Workspace.emptySubtitle }
        if state.hasSelection {
            return DesignSystem.Workspace.selectionSummary(selected: state.selection.count, total: state.items.count)
        }
        return DesignSystem.Workspace.summary(pdfs: state.pdfs.count, images: state.images.count)
    }
}

/// Outlines the window while files are dragged over a non-empty list.
private struct DropHighlight: View {
    var body: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Layout.selectionRadius, style: .continuous)
            .strokeBorder(Color.accentColor, lineWidth: 3)
            .background(Color.accentColor.opacity(0.06))
            .padding(4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Inline progress under the grid while an export runs, instead of a modal overlay.
private struct ActivityBar: View {
    let title: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            ProgressView()
                .controlSize(.small)
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

private extension View {
    /// The window subtitle on the Mac; other platforms have none.
    @ViewBuilder
    func windowSubtitle(_ subtitle: String) -> some View {
        #if os(macOS)
        navigationSubtitle(subtitle)
        #else
        self
        #endif
    }
}

/// Sets the importer's confirm button where the OS supports it (macOS 15, iOS 18).
private struct FileDialogConfirmationLabel: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if #available(macOS 15.0, iOS 18.0, *) {
            content.fileDialogConfirmationLabel(label.map { Text($0) })
        } else {
            content
        }
    }
}
