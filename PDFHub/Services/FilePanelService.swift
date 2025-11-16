import Foundation
import AppKit
import UniformTypeIdentifiers

protocol FilePanelServiceProtocol {
    func openFilePanel(contentTypes: [UTType], multipleSelection: Bool) -> [URL]
    func showSavePanel(defaultName: String, prompt: String, allowedTypes: [UTType]) -> URL?
    func showDirectoryPanel(prompt: String) -> URL?
}

struct FilePanelService: FilePanelServiceProtocol {
    func openFilePanel(contentTypes: [UTType], multipleSelection: Bool) -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = contentTypes
        panel.allowsMultipleSelection = multipleSelection
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        return panel.runModal() == .OK ? panel.urls : []
    }
    
    func showSavePanel(defaultName: String, prompt: String, allowedTypes: [UTType]) -> URL? {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = allowedTypes
        savePanel.nameFieldStringValue = defaultName
        savePanel.prompt = prompt
        savePanel.canCreateDirectories = true
        
        return savePanel.runModal() == .OK ? savePanel.url : nil
    }
    
    func showDirectoryPanel(prompt: String) -> URL? {
        let savePanel = NSOpenPanel()
        savePanel.canChooseDirectories = true
        savePanel.canChooseFiles = false
        savePanel.allowsMultipleSelection = false
        savePanel.prompt = prompt
        
        return savePanel.runModal() == .OK ? savePanel.url : nil
    }
}

