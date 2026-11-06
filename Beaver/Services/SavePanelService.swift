#if os(macOS)
import AppKit
import UniformTypeIdentifiers

/// Asks for the destination of a new file with the system save panel, and for a folder of new
/// files with the open panel.
@MainActor
struct SavePanelService: SaveLocationProviding {
    func saveLocation(defaultName: String, prompt: String, contentType: UTType) -> URL? {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [contentType]
        savePanel.nameFieldStringValue = defaultName
        savePanel.prompt = prompt
        savePanel.canCreateDirectories = true

        return savePanel.runModal() == .OK ? savePanel.url : nil
    }

    func folderLocation(defaultName: String, prompt: String) -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = prompt
        openPanel.message = prompt

        return openPanel.runModal() == .OK ? openPanel.url : nil
    }
}
#endif
