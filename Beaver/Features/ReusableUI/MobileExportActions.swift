#if os(iOS)
import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// What comes next after an export on iPhone and iPad. A new PDF already sits in Beaver's
/// folder in Files; Share sends it on and Save to Files puts a copy somewhere else. Split pages
/// go into the folder the person picked, so Files opens there.
struct MobileExportActions: View {
    let output: URL
    let isFolder: Bool
    var fillsWidth = false

    @Environment(\.openURL) private var openURL
    @State private var isExporting = false
    @State private var savedCopies = 0

    var body: some View {
        if isFolder {
            if let filesURL = Self.filesAppURL(for: output) {
                Button {
                    openURL(filesURL)
                } label: {
                    label(DesignSystem.Mobile.showInFiles, systemImage: DesignSystem.Icons.showInFinder)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint(DesignSystem.Mobile.showInFilesHelp)
            }
        } else {
            Button {
                isExporting = true
            } label: {
                label(DesignSystem.Mobile.saveToFiles, systemImage: DesignSystem.Icons.showInFinder)
            }
            .accessibilityHint(DesignSystem.Mobile.saveToFilesHelp)
            .fileExporter(
                isPresented: $isExporting,
                item: SharedFile(url: output),
                contentTypes: [.pdf],
                defaultFilename: output.deletingPathExtension().lastPathComponent
            ) { result in
                if case .success = result {
                    savedCopies += 1
                    AccessibilityNotification.Announcement(
                        DesignSystem.Mobile.savedCopy(output.lastPathComponent)
                    ).post()
                }
            }
            .sensoryFeedback(.success, trigger: savedCopies)

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

    /// `shareddocuments://` opens the Files app at a local folder.
    static func filesAppURL(for folder: URL) -> URL? {
        var components = URLComponents()
        components.scheme = "shareddocuments"
        components.path = folder.path(percentEncoded: false)
        return components.url
    }
}

/// A file on disk handed to Save to Files without reading it into memory.
struct SharedFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { file in
            SentTransferredFile(file.url)
        }
    }
}
#endif
