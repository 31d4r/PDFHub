#if os(macOS)
import AppKit
#endif
import Foundation
import UniformTypeIdentifiers

/// Asks the user where to save a new PDF.
///
/// Opening files and choosing the split folder use SwiftUI's `fileImporter`, which
/// works on every platform. Saving stays behind this protocol because the PDF is
/// only built after the user picks a destination, so the export can show progress
/// and report skipped files. An iOS version can conform with a document picker.
@MainActor
protocol SaveLocationProviding {
    func saveLocation(defaultName: String, prompt: String) -> URL?
}

#if os(macOS)
@MainActor
struct SavePanelService: SaveLocationProviding {
    func saveLocation(defaultName: String, prompt: String) -> URL? {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = defaultName
        savePanel.prompt = prompt
        savePanel.canCreateDirectories = true

        return savePanel.runModal() == .OK ? savePanel.url : nil
    }
}
#endif
