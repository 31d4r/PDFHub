import BeaverCore
import Foundation
import UniformTypeIdentifiers

/// What the system file importer is currently being shown for.
enum FileImportRequest: Equatable, Sendable {
    case pdfs
    case images
    /// A folder to save the pages of these PDFs into.
    case splitDestination([URL])

    var allowedContentTypes: [UTType] {
        switch self {
        case .pdfs: return [.pdf]
        case .images: return SupportedImageType.allUTTypes
        case .splitDestination: return [.folder]
        }
    }

    var allowsMultipleSelection: Bool {
        switch self {
        case .pdfs, .images: return true
        case .splitDestination: return false
        }
    }

    /// The importer's confirm button label, or `nil` for the system default.
    var confirmationLabel: String? {
        switch self {
        case .pdfs, .images: return nil
        case .splitDestination: return DesignSystem.FileNames.saveSplitPDFsPrompt
        }
    }
}
