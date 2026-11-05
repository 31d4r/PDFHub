import BeaverCore
import Foundation
import UniformTypeIdentifiers

/// What the system file importer is currently being shown for.
enum FileImportRequest: Equatable, Sendable {
    /// PDFs and images to add.
    case files
    /// A folder to save the pages of these files into.
    case splitDestination([ExportSource])

    var allowedContentTypes: [UTType] {
        switch self {
        case .files: return [.pdf] + SupportedImageType.allUTTypes
        case .splitDestination: return [.folder]
        }
    }

    var allowsMultipleSelection: Bool {
        switch self {
        case .files: return true
        case .splitDestination: return false
        }
    }

    /// The importer's confirm button label, or `nil` for the system default.
    var confirmationLabel: String? {
        switch self {
        case .files: return DesignSystem.FileNames.addFilesPrompt
        case .splitDestination: return DesignSystem.FileNames.saveSplitPDFsPrompt
        }
    }
}
