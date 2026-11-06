import SwiftUI
#if os(macOS)
import AppKit
#endif

/// A non-blocking note after a successful export, with the next steps a person usually wants:
/// reveal the file in Finder, open it, or add a new PDF to the list. On the Mac it stays until
/// dismissed or the next export starts; on iPhone and iPad it also goes by itself after a few
/// seconds, unless VoiceOver is on, it has been touched, or it offers to add the PDF.
struct ExportBanner: View {
    let alert: ExportAlert
    /// Shown only for a single new PDF that isn't listed yet; exports never add their output themselves.
    var onAddToWorkspace: (() -> Void)?
    let onDismiss: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverRunning
    @AccessibilityFocusState private var isFocused: Bool
    @State private var hasInteracted = false

    private var isFolder: Bool {
        guard let output = alert.output else { return false }
        return (try? output.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? output.hasDirectoryPath
    }

    var body: some View {
        content
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.small)
            .background {
                if reduceTransparency {
                    Rectangle().fill(.background)
                } else {
                    Rectangle().fill(.bar)
                }
            }
            .overlay(alignment: .top) {
                Divider().opacity(contrast == .increased ? 1 : 0.6)
            }
            .accessibilityElement(children: .contain)
            .accessibilityFocused($isFocused)
            .onAppear {
                AccessibilityNotification.Announcement(alert.message).post()
            }
            #if os(iOS)
            .simultaneousGesture(TapGesture().onEnded { hasInteracted = true })
            .task(id: autoDismissDelay) {
                guard let autoDismissDelay else { return }
                try? await Task.sleep(for: autoDismissDelay)
                guard !Task.isCancelled else { return }
                onDismiss()
            }
            #endif
    }

    private var autoDismissDelay: Duration? {
        ExportBannerPolicy.autoDismissDelay(
            isVoiceOverRunning: isVoiceOverRunning || isFocused,
            hasInteracted: hasInteracted,
            offersChoice: onAddToWorkspace != nil
        )
    }

    /// One row on the Mac. On iPhone and iPad the buttons go under the message, side by side
    /// when they fit and stacked full width when they don't (narrow windows, large text).
    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        HStack(spacing: DesignSystem.Spacing.small) {
            icon
            message
            if let output = alert.output {
                actions(for: output)
            }
            dismissButton
        }
        #else
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.small) {
                icon
                message
                dismissButton
            }
            if let output = alert.output {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: DesignSystem.Spacing.small) {
                        actions(for: output)
                    }
                    VStack(spacing: DesignSystem.Spacing.small) {
                        actions(for: output, fillsWidth: true)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        #endif
    }

    private var icon: some View {
        Image(systemName: DesignSystem.Icons.exportSucceeded)
            .foregroundStyle(.green)
            .imageScale(.large)
            .accessibilityHidden(true)
    }

    private var message: some View {
        Text(alert.message)
            .font(.callout)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: DesignSystem.Icons.dismiss)
        }
        .buttonStyle(.borderless)
        .help(DesignSystem.Export.dismissHelp)
        .accessibilityLabel(DesignSystem.Export.dismiss)
    }

    @ViewBuilder
    private func actions(for output: URL, fillsWidth: Bool = false) -> some View {
        if let onAddToWorkspace {
            Button(action: onAddToWorkspace) {
                Label(DesignSystem.Export.addToWorkspace, systemImage: DesignSystem.Icons.addToWorkspace)
                    .frame(maxWidth: fillsWidth ? .infinity : nil)
            }
            .help(DesignSystem.Export.addToWorkspaceHelp)
        }

        #if os(iOS)
        MobileExportActions(output: output, isFolder: isFolder, sharedFiles: alert.sharedFiles, fillsWidth: fillsWidth)
        #else
        Button(DesignSystem.Export.showInFinder) {
            NSWorkspace.shared.activateFileViewerSelecting([output])
        }
        .help(DesignSystem.Export.showInFinderHelp)

        Button(isFolder ? DesignSystem.Export.openFolder : DesignSystem.Export.open) {
            openURL(output)
        }
        .buttonStyle(.borderedProminent)
        .help(isFolder ? DesignSystem.Export.openFolderHelp : DesignSystem.Export.openHelp)
        #endif
    }
}
