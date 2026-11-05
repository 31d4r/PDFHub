import Foundation

/// Asks where to save a new PDF.
///
/// Opening files and choosing the split folder use SwiftUI's `fileImporter`, which
/// works on every platform. Saving stays behind this protocol because the PDF is
/// only built after the destination is known, so the export can show progress
/// and report skipped files. The Mac asks with a save panel; iOS saves into the
/// app's Documents folder and then offers Share and Show in Files.
@MainActor
protocol SaveLocationProviding {
    func saveLocation(defaultName: String, prompt: String) -> URL?
}

#if os(macOS)
/// The save location each platform uses by default.
typealias PlatformSaveLocationService = SavePanelService
#else
typealias PlatformSaveLocationService = DocumentsSaveLocationService
#endif
