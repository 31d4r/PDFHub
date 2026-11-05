import CoreGraphics
import Foundation

/// First-page previews and page counts for the file grid. Each file is opened and drawn once,
/// off the main actor, however often its card scrolls in or moves.
public actor PDFPreviewCache {
    public struct Preview: Sendable {
        /// The first page with the rotation saved in it, or `nil` when it can't be drawn.
        public let image: CGImage?
        /// 0 when the file can't be read.
        public let pageCount: Int
    }

    private let capacity: Int
    private var previews: [URL: Preview] = [:]
    /// Least recently used first.
    private var order: [URL] = []

    public init(capacity: Int = 200) {
        self.capacity = max(1, capacity)
    }

    public func preview(for url: URL, maxPixelSize: Int) -> Preview {
        if let cached = previews[url] {
            touch(url)
            return cached
        }
        let document = CGPDFDocument(url as CFURL)
        let image = document?.page(at: 1).flatMap { PDFPageThumbnailer.render($0, maxPixelSize: maxPixelSize) }
        let preview = Preview(image: image, pageCount: document?.numberOfPages ?? 0)
        store(preview, for: url)
        return preview
    }

    /// Whether a preview for `url` is cached.
    public func contains(_ url: URL) -> Bool {
        previews[url] != nil
    }

    private func store(_ preview: Preview, for url: URL) {
        previews[url] = preview
        touch(url)
        while order.count > capacity {
            previews[order.removeFirst()] = nil
        }
    }

    private func touch(_ url: URL) {
        order.removeAll { $0 == url }
        order.append(url)
    }
}
