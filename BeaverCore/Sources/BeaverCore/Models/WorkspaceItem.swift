import Foundation

/// One file in Beaver's single window: a PDF or an image, kept in the order the user arranged.
public enum WorkspaceItem: Identifiable, Equatable, Sendable {
    case pdf(PDFItem)
    case image(ImageItem)

    public var id: UUID {
        switch self {
        case .pdf(let pdf): return pdf.id
        case .image(let image): return image.id
        }
    }

    public var url: URL {
        switch self {
        case .pdf(let pdf): return pdf.url
        case .image(let image): return image.url
        }
    }

    public var kind: DroppedFileKind {
        switch self {
        case .pdf: return .pdf
        case .image: return .image
        }
    }

    public var name: String { url.lastPathComponent }

    public var pdf: PDFItem? {
        if case .pdf(let pdf) = self { return pdf }
        return nil
    }

    public var image: ImageItem? {
        if case .image(let image) = self { return image }
        return nil
    }

    /// The turn for the whole file.
    public var rotationAngle: RotationAngle {
        switch self {
        case .pdf(let pdf): return pdf.rotationAngle
        case .image(let image): return image.rotationAngle
        }
    }

    /// Whether the user turned the file or any of its pages.
    public var isRotated: Bool {
        switch self {
        case .pdf(let pdf): return pdf.rotationAngle != .zero || pdf.hasPageRotations
        case .image(let image): return image.rotationAngle != .zero
        }
    }

    /// Turns the whole file a quarter turn.
    public mutating func rotate(_ direction: RotationDirection) {
        switch self {
        case .pdf(var pdf):
            pdf.rotationAngle = pdf.rotationAngle.rotated(direction)
            self = .pdf(pdf)
        case .image(var image):
            image.rotate(direction)
            self = .image(image)
        }
    }

    /// What an export reads for this item.
    public var exportSource: ExportSource {
        switch self {
        case .pdf(let pdf): return .pdf(pdf.url, pdf.rotation)
        case .image(let image): return .image(image.url, image.rotationAngle)
        }
    }
}

public extension Array where Element == WorkspaceItem {
    var pdfs: [PDFItem] { compactMap(\.pdf) }
    var images: [ImageItem] { compactMap(\.image) }

    /// What an action works on: the selected items in list order, or every item when nothing is selected.
    func targets(selection: Set<UUID>) -> [WorkspaceItem] {
        let selected = filter { selection.contains($0.id) }
        return selected.isEmpty ? self : selected
    }

    func contains(id: UUID) -> Bool {
        contains { $0.id == id }
    }
}
