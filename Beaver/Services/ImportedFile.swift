#if os(iOS)
import BeaverCore
import CoreTransferable
import Foundation
import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// A PDF or image handed over by Photos or another app, copied into Beaver's own temporary
/// folder because the system deletes its copy once the transfer ends.
struct ImportedFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .pdf) { try copy($0.file) }
        FileRepresentation(importedContentType: .image) { try copy($0.file) }
    }

    /// Where imported files live while they are in the list. iOS empties it between launches.
    static var directory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Imported", isDirectory: true)
    }

    /// Copies `file` into its own folder, keeping its name so the card shows it, and adds the
    /// right extension when the sender left it off.
    static func copy(_ file: URL) throws -> ImportedFile {
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var destination = folder.appendingPathComponent(file.lastPathComponent)
        if UTType(filenameExtension: destination.pathExtension) == nil,
           let source = CGImageSourceCreateWithURL(file as CFURL, nil),
           let identifier = CGImageSourceGetType(source) as String?,
           let fileExtension = UTType(identifier)?.preferredFilenameExtension {
            destination.appendPathExtension(fileExtension)
        }
        try FileManager.default.copyItem(at: file, to: destination)
        return ImportedFile(url: destination)
    }
}

/// Loads photos picked in the Photos picker as files, in the order they were picked.
enum PhotoLibraryImporter {
    struct Result {
        let urls: [URL]
        let failedCount: Int
    }

    /// Keeps each photo's original format, such as HEIC, and its EXIF orientation, which
    /// Beaver applies when it draws the image.
    static func load(_ items: [PhotosPickerItem]) async -> Result {
        var urls: [URL] = []
        var failedCount = 0
        for item in items {
            if Task.isCancelled { break }
            do {
                if let file = try await item.loadTransferable(type: ImportedFile.self) {
                    urls.append(file.url)
                } else {
                    failedCount += 1
                }
            } catch {
                failedCount += 1
            }
        }
        return Result(urls: urls, failedCount: failedCount)
    }
}
#endif
