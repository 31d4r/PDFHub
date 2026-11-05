#if os(macOS)
import AppKit
import UniformTypeIdentifiers

/// Asks for the destination of a new PDF with the system save panel.
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
