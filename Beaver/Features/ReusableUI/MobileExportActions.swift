#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

/// What comes next after an export on iPhone and iPad. The new PDF already sits in Beaver's
/// folder in Files, so Share sends it on and Show in Files opens that folder; split pages go
/// into the folder the person picked, so Files opens there. Page images saved into a folder
/// can be shared together, so they reach Messages or Photos in one step.
struct MobileExportActions: View {
    let output: URL
    let isFolder: Bool
    /// The new files in `output` when it's a folder of page images.
    var sharedFiles: [URL] = []
    var fillsWidth = false

    @Environment(\.openURL) private var openURL

    var body: some View {
        if let filesURL = ExportBannerPolicy.filesAppURL(showing: output, isFolder: isFolder) {
            let button = Button {
                openURL(filesURL)
            } label: {
                label(DesignSystem.Mobile.showInFiles, systemImage: DesignSystem.Icons.showInFinder)
            }
            .accessibilityHint(isFolder ? DesignSystem.Mobile.showInFilesHelp : DesignSystem.Mobile.showFileInFilesHelp)

            if isFolder && sharedFiles.isEmpty {
                button.buttonStyle(.borderedProminent)
            } else {
                button
            }
        }
        if !isFolder {
            ShareLink(item: output) {
                label(DesignSystem.Mobile.share, systemImage: DesignSystem.Icons.share)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint(isImage(output) ? DesignSystem.Mobile.shareImagesHelp : DesignSystem.Mobile.shareHelp)
        } else if !sharedFiles.isEmpty {
            ShareLink(items: sharedFiles) {
                label(DesignSystem.Mobile.share, systemImage: DesignSystem.Icons.share)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint(DesignSystem.Mobile.shareImagesHelp)
        }
    }

    private func isImage(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false
    }

    private func label(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
    }
}
#endif
