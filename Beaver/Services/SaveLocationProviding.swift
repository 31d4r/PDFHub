import Foundation
import UniformTypeIdentifiers

/// Asks where to save a new PDF or page image, or which folder to save several files into.
///
/// Opening files and choosing the split folder use SwiftUI's `fileImporter`, which
/// works on every platform. Saving stays behind this protocol because the PDF is
/// only built after the destination is known, so the export can show progress
/// and report skipped files. The Mac asks with a save panel; iOS saves into the
/// app's Documents folder and then offers Share and Show in Files.
@MainActor
protocol SaveLocationProviding {
    /// Where to save one new file of `contentType`, or `nil` when the person cancels.
    func saveLocation(defaultName: String, prompt: String, contentType: UTType) -> URL?
    /// A folder to save several new files into, or `nil` when the person cancels. The Mac asks
    /// with an open panel, as Split does; iOS makes a new folder named `defaultName` in Beaver's
    /// Documents folder.
    func folderLocation(defaultName: String, prompt: String) -> URL?
}

extension SaveLocationProviding {
    /// Where to save one new PDF.
    func saveLocation(defaultName: String, prompt: String) -> URL? {
        saveLocation(defaultName: defaultName, prompt: prompt, contentType: .pdf)
    }
}

#if os(macOS)
/// The save location each platform uses by default.
typealias PlatformSaveLocationService = SavePanelService
#else
typealias PlatformSaveLocationService = DocumentsSaveLocationService
#endif
