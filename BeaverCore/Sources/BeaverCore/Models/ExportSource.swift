import Foundation

/// One file to read for an export, with the user's rotation for it.
public enum ExportSource: Equatable, Sendable {
    case pdf(URL, PDFRotation)
    /// Turned clockwise on top of the image's EXIF orientation.
    case image(URL, RotationAngle)

    public var url: URL {
        switch self {
        case .pdf(let url, _), .image(let url, _): return url
        }
    }
}
