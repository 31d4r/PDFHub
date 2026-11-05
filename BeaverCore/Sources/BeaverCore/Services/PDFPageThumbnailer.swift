import CoreGraphics
import Foundation

/// Renders downsampled page images with Core Graphics, off the main actor.
/// Keeps the document open and caches each page it has drawn.
public actor PDFPageThumbnailer {
    private let url: URL
    private var document: CGPDFDocument?
    private var didOpen = false
    private var cache: [Int: CGImage] = [:]

    public init(url: URL) {
        self.url = url
    }

    /// 0 when the file can't be read.
    public func pageCount() -> Int {
        openDocument()?.numberOfPages ?? 0
    }

    /// The page (zero-based) with the rotation saved in it, at most `maxPixelSize` on its long side.
    public func thumbnail(at index: Int, maxPixelSize: Int) -> CGImage? {
        if let cached = cache[index] { return cached }
        guard let page = openDocument()?.page(at: index + 1),
              let image = Self.render(page, maxPixelSize: maxPixelSize)
        else { return nil }
        cache[index] = image
        return image
    }

    private func openDocument() -> CGPDFDocument? {
        if !didOpen {
            didOpen = true
            document = CGPDFDocument(url as CFURL)
        }
        return document
    }

    static func render(_ page: CGPDFPage, maxPixelSize: Int) -> CGImage? {
        let box = page.getBoxRect(.cropBox)
        guard box.width > 0, box.height > 0, maxPixelSize > 0 else { return nil }
        let saved = RotationAngle(normalizing: Int(page.rotationAngle))
        let shown = saved.rotatedSize(box.size)
        let scale = CGFloat(maxPixelSize) / max(shown.width, shown.height)
        let width = max(1, Int((shown.width * scale).rounded()))
        let height = max(1, Int((shown.height * scale).rounded()))

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        // Scale up first so the drawing transform (which only scales down) fills the bitmap.
        context.scaleBy(x: scale, y: scale)
        let target = CGRect(x: 0, y: 0, width: CGFloat(width) / scale, height: CGFloat(height) / scale)
        context.concatenate(page.getDrawingTransform(.cropBox, rect: target, rotate: 0, preserveAspectRatio: true))
        context.clip(to: box)
        context.drawPDFPage(page)
        return context.makeImage()
    }
}
