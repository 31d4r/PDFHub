#if os(iOS)
import SwiftUI

/// What comes next after an export on iPhone and iPad. The new PDF already sits in Beaver's
/// folder in Files, so Share sends it on and Show in Files opens that folder; split pages go
/// into the folder the person picked, so Files opens there.
struct MobileExportActions: View {
    let output: URL
    let isFolder: Bool
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

            if isFolder {
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
            .accessibilityHint(DesignSystem.Mobile.shareHelp)
        }
    }

    private func label(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
    }
}
#endif
