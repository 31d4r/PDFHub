import CoreGraphics
import Foundation

struct ImageItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let url: URL
    /// A downsampled preview. The full-size image is only read when converting.
    let thumbnail: CGImage

    init(
        id: UUID = UUID(),
        url: URL,
        thumbnail: CGImage
    ) {
        self.id = id
        self.url = url
        self.thumbnail = thumbnail
    }

    static func == (
        lhs: ImageItem,
        rhs: ImageItem
    ) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url
    }
}
