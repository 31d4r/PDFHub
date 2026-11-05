import CoreGraphics
import Foundation

public struct ImageItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let url: URL
    /// A downsampled preview. The full-size image is only read when converting.
    public let thumbnail: CGImage

    public init(
        id: UUID = UUID(),
        url: URL,
        thumbnail: CGImage
    ) {
        self.id = id
        self.url = url
        self.thumbnail = thumbnail
    }

    public static func == (
        lhs: ImageItem,
        rhs: ImageItem
    ) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url
    }
}
