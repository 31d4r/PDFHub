import Foundation
import UniformTypeIdentifiers

/// What a page export makes from the chosen pages of a PDF.
public enum PageExportFormat: String, CaseIterable, Sendable {
    /// The chosen pages, in order, as one new PDF.
    case pdf
    /// One lossless image per page. The default for images: text and line art stay sharp.
    case png
    /// One compressed image per page: smaller files, best for scans and photos.
    case jpeg

    public var isImage: Bool { self != .pdf }

    public var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .png: return "png"
        case .jpeg: return "jpg"
        }
    }

    public var contentType: UTType {
        switch self {
        case .pdf: return .pdf
        case .png: return .png
        case .jpeg: return .jpeg
        }
    }
}

/// One PDF to export pages from, with the user's rotations for it.
public struct PageExportSource: Equatable, Sendable {
    public let url: URL
    public let rotation: PDFRotation
    /// Zero-based pages in the order to export them, or `nil` for every page.
    public let pages: [Int]?

    public init(url: URL, rotation: PDFRotation = .none, pages: [Int]? = nil) {
        self.url = url
        self.rotation = rotation
        self.pages = pages
    }
}

/// Why pages couldn't be exported. The app turns each case into a message.
public enum PageExportError: Error, Equatable, Sendable {
    /// The file isn't a PDF Beaver can read.
    case unreadable(URL)
    /// The PDF needs a password to open.
    case locked(URL)
    /// The PDF, or the chosen pages, have nothing to export.
    case noPages(URL)
    /// A page couldn't be drawn or encoded as an image.
    case renderFailed(URL, page: Int)
}
