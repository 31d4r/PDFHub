#if os(iOS)
import BeaverCore
import Foundation

/// Saves new PDFs into the app's Documents folder, which the Files app shows under
/// On My iPhone › Beaver. iOS has no modal save panel, so the export writes here first
/// and the banner then offers Share and Save to Files for another place.
@MainActor
struct DocumentsSaveLocationService: SaveLocationProviding {
    private let directory: URL?
    private let writer: PDFFileWriterService

    init(directory: URL? = nil, writer: PDFFileWriterService = PDFFileWriterService()) {
        self.directory = directory
        self.writer = writer
    }

    func saveLocation(defaultName: String, prompt: String) -> URL? {
        guard let folder = directory ?? Self.documentsDirectory else { return nil }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return writer.uniqueURL(for: defaultName, in: folder)
    }

    static var documentsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
}
#endif
