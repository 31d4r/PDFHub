import AppKit
import Foundation

struct ImageItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let image: NSImage

    init(
        id: UUID = UUID(),
        url: URL,
        image: NSImage
    ) {
        self.id = id
        self.url = url
        self.image = image
    }

    static func == (
        lhs: ImageItem,
        rhs: ImageItem
    ) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url
    }
}
