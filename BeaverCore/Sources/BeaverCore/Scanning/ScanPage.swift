import Foundation

/// One page of a scan being reviewed: the photo on disk and how to turn it into a PDF page.
/// Photos stay on disk so a long scan doesn't fill memory.
public struct ScanPage: Identifiable, Hashable, Sendable {
    public let id: UUID
    /// The photo, upright, at most `ScanImageProcessor.maximumPixelSize` on its longest side.
    public var imageURL: URL
    public var quad: DocumentQuad
    public var filter: ScanFilter
    public var rotation: RotationAngle

    public init(
        id: UUID = UUID(),
        imageURL: URL,
        quad: DocumentQuad = .fullImage,
        filter: ScanFilter = .default,
        rotation: RotationAngle = .zero
    ) {
        self.id = id
        self.imageURL = imageURL
        self.quad = quad
        self.filter = filter
        self.rotation = rotation
    }
}
