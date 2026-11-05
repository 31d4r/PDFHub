#if os(macOS)
import AsyncReactor
import BeaverCore
import QuickLook
import SwiftUI

/// Beaver's one window. PDFs and images share a single grid, in output order, so there's no
/// mode to pick first: the toolbar's Merge, Split, Convert and Combine follow from what's
/// in the list and what's selected.
struct MainView: View {
    @EnvironmentObject private var reactor: BeaverReactor
    @State private var isDropTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    ActivityBar(title: activity.title) {
                        reactor.action(.cancelExport)
                    }
                    .transition(barTransition)
                } else if let alert = reactor.state.exportAlert, alert.isSuccess {
                    ExportBanner(
                        alert: alert,
                        onAddToWorkspace: reactor.state.exportToAdd.map { _ in
                            { reactor.send(.addExportToWorkspace) }
                        }
                    ) {
                        reactor.action(.didDismissAlert)
                    }
                    .transition(barTransition)
                }
            }
            .animation(reduceMotion ? nil : .snappy, value: reactor.state.activity)
            .animation(reduceMotion ? nil : .snappy, value: reactor.state.exportAlert)
            .navigationTitle(DesignSystem.Workspace.title)
            .navigationSubtitle(subtitle)
            .toolbar {
                WorkspaceToolbar(reactor: reactor)
            }
    }

    /// Bars slide up from the bottom edge, or just fade with Reduce Motion.
    private var barTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
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

    /// "3 PDFs and 2 images · 2 selected", "3 PDFs and 2 images", or "No files".
    private var subtitle: String {
        let state = reactor.state
        return DesignSystem.Workspace.subtitle(
            pdfs: state.pdfs.count,
            images: state.images.count,
            selected: state.selection.count
        )
    }
}
#endif
