import Foundation

/// Every rotation the user has made, keyed by item id. Restoring one only touches rotations,
/// so undo never brings back a deleted card or reverts a reorder.
public struct RotationSnapshot: Equatable, Sendable {
    public var pdfRotations: [UUID: RotationAngle]
    public var imageRotations: [UUID: RotationAngle]

    public init(pdfs: [PDFItem], images: [ImageItem]) {
        pdfRotations = Dictionary(pdfs.map { ($0.id, $0.rotationAngle) }, uniquingKeysWith: { first, _ in first })
        imageRotations = Dictionary(images.map { ($0.id, $0.rotationAngle) }, uniquingKeysWith: { first, _ in first })
    }

    /// Puts back the saved rotations. Items added since keep theirs.
    public func restore(_ pdfs: inout [PDFItem]) {
        for index in pdfs.indices {
            if let angle = pdfRotations[pdfs[index].id] {
                pdfs[index].rotationAngle = angle
            }
        }
    }

    /// Puts back the saved rotations and redraws the previews. Items added since keep theirs.
    public func restore(_ images: inout [ImageItem]) {
        for index in images.indices {
            if let angle = imageRotations[images[index].id] {
                images[index].setRotation(angle)
            }
        }
    }
}
