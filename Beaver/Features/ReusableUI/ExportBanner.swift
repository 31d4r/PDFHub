import SwiftUI
#if os(macOS)
import AppKit
#endif

/// A non-blocking note after a successful export, with the next steps a person usually wants:
/// reveal the file in Finder, open it, or add a new PDF to the list. It stays until dismissed
/// or the next export starts.
struct ExportBanner: View {
    let alert: ExportAlert
    /// Shown only for a single new PDF that isn't listed yet; exports never add their output themselves.
    var onAddToWorkspace: (() -> Void)?
    let onDismiss: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var isFolder: Bool {
        guard let output = alert.output else { return false }
        return (try? output.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? output.hasDirectoryPath
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: DesignSystem.Icons.exportSucceeded)
                .foregroundStyle(.green)
                .imageScale(.large)
                .accessibilityHidden(true)

            Text(alert.message)
                .font(.callout)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let output = alert.output {
                actions(for: output)
            }

            Button(action: onDismiss) {
                Image(systemName: DesignSystem.Icons.dismiss)
            }
            .buttonStyle(.borderless)
            .help(DesignSystem.Export.dismissHelp)
            .accessibilityLabel(DesignSystem.Export.dismiss)
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
        .overlay(alignment: .top) {
            Divider().opacity(contrast == .increased ? 1 : 0.6)
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            AccessibilityNotification.Announcement(alert.message).post()
        }
    }

    @ViewBuilder
    private func actions(for output: URL) -> some View {
        if let onAddToWorkspace {
            Button(action: onAddToWorkspace) {
                Label(DesignSystem.Export.addToWorkspace, systemImage: DesignSystem.Icons.addToWorkspace)
            }
            .help(DesignSystem.Export.addToWorkspaceHelp)
        }

        #if os(macOS)
        Button(DesignSystem.Export.showInFinder) {
            NSWorkspace.shared.activateFileViewerSelecting([output])
        }
        .help(DesignSystem.Export.showInFinderHelp)
        #endif

        Button(isFolder ? DesignSystem.Export.openFolder : DesignSystem.Export.open) {
            openURL(output)
        }
        .buttonStyle(.borderedProminent)
        .help(isFolder ? DesignSystem.Export.openFolderHelp : DesignSystem.Export.openHelp)
    }
}
