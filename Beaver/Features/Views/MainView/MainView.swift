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
            .windowSubtitle(subtitle)
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
/// Cancel (⌘.) stops it before anything is written.
private struct ActivityBar: View {
    let title: String
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            ProgressView()
                .controlSize(.small)
                .accessibilityHidden(true)
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.updatesFrequently)
            Spacer()
            Button(DesignSystem.Export.cancel, action: onCancel)
                .keyboardShortcut(".", modifiers: .command)
                .help(DesignSystem.Export.cancelHelp)
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background {
            if reduceTransparency {
                Rectangle().fill(.background)
            } else {
                Rectangle().fill(.bar)
            }
        }
        .overlay(alignment: .top) { Divider() }
        .accessibilityElement(children: .contain)
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
