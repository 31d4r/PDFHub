import Foundation
import UniformTypeIdentifiers

/// Which files a drop target accepts. Checks the file's real content type
/// first and falls back to its extension when the type cannot be read.
public enum DroppedFileKind: Sendable {
    case pdf
    case image

    public func accepts(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }

        if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return accepts(contentType)
        }
        if let typeFromExtension = UTType(filenameExtension: url.pathExtension) {
            return accepts(typeFromExtension)
        }
        return false
    }

    public func accepts(_ type: UTType) -> Bool {
        switch self {
        case .pdf:
            return type.conforms(to: .pdf)
        case .image:
            return SupportedImageType.allUTTypes.contains { type.conforms(to: $0) }
        }
    }

    public func filter(_ urls: [URL]) -> [URL] {
        urls.filter(accepts)
    }
}
