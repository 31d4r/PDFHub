import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Writes scanned pages into one PDF, each page as a JPEG sized like paper, with an optional
/// invisible text layer so the file is searchable and copyable.
public enum ScanPDFWriter {
    public enum Error: Swift.Error, Equatable {
        case noPages
        case cannotCreate
    }

    /// A page's longest side in points: A4's long edge, so pages print at their real size.
    public static let pageLongSide: CGFloat = 842
    public static let defaultQuality: Double = 0.82

    /// Writes `pages` in order to `url`, replacing any file there. When `text` has an entry for
    /// a page index, that page gets an invisible searchable layer aligned to the runs.
    public static func write(
        _ pages: [CGImage],
        text: [RecognizedText?] = [],
        to url: URL,
        quality: Double = defaultQuality
    ) throws {
        guard !pages.isEmpty else { throw Error.noPages }
        let data = NSMutableData()
        guard
            let consumer = CGDataConsumer(data: data as CFMutableData),
            let context = CGContext(consumer: consumer, mediaBox: nil, nil)
        else { throw Error.cannotCreate }

        for (index, page) in pages.enumerated() {
            var box = CGRect(origin: .zero, size: pageSize(for: page))
            let image = jpeg(page, quality: quality) ?? page
            context.beginPage(mediaBox: &box)
            context.interpolationQuality = .high
            context.draw(image, in: box)
            if text.indices.contains(index), let recognized = text[index], !recognized.isEmpty {
                drawInvisibleText(recognized, in: box, context: context)
            }
            context.endPage()
        }
        context.closePDF()
        try (data as Data).write(to: url, options: .atomic)
    }

    /// Paper-sized points with the image's proportions.
    public static func pageSize(for image: CGImage) -> CGSize {
        let width = CGFloat(image.width), height = CGFloat(image.height)
        guard width > 0, height > 0 else { return .zero }
        let scale = pageLongSide / max(width, height)
        return CGSize(width: (width * scale).rounded(), height: (height * scale).rounded())
    }

    /// Draws each run in `text` as invisible PDF text scaled to its Vision bounding box.
    public static func drawInvisibleText(
        _ text: RecognizedText,
        in pageBounds: CGRect,
        context: CGContext
    ) {
        guard pageBounds.width > 0, pageBounds.height > 0 else { return }
        for run in text.runs {
            let trimmed = run.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let box = CGRect(
                x: pageBounds.minX + run.boundingBox.minX * pageBounds.width,
                y: pageBounds.minY + run.boundingBox.minY * pageBounds.height,
                width: run.boundingBox.width * pageBounds.width,
                height: run.boundingBox.height * pageBounds.height
            )
            drawRun(trimmed, in: box, context: context)
        }
    }

    /// One word or line, font sized so its glyphs fill `bounds`.
    private static func drawRun(_ string: String, in bounds: CGRect, context: CGContext) {
        guard bounds.width > 0.5, bounds.height > 0.5 else { return }
        var fontSize = max(bounds.height * 0.95, 1)
        var line = makeLine(string, fontSize: fontSize)
        var typographicWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
        if typographicWidth > 0 {
            fontSize *= bounds.width / CGFloat(typographicWidth)
            fontSize = max(fontSize, 1)
            line = makeLine(string, fontSize: fontSize)
        }
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        _ = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        context.saveGState()
        context.textMatrix = .identity
        context.setTextDrawingMode(.invisible)
        context.textPosition = CGPoint(x: bounds.minX, y: bounds.minY + descent)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    private static func makeLine(_ string: String, fontSize: CGFloat) -> CTLine {
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let attributes = [kCTFontAttributeName: font] as CFDictionary
        let attributed = CFAttributedStringCreate(nil, string as CFString, attributes)!
        return CTLineCreateWithAttributedString(attributed)
    }

    /// The image compressed as JPEG, which PDF stores as is, keeping scans small.
    private static func jpeg(_ image: CGImage, quality: Double) -> CGImage? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: quality
        ] as CFDictionary)
        guard
            CGImageDestinationFinalize(destination),
            let provider = CGDataProvider(data: data as CFData)
        else { return nil }
        return CGImage(
            jpegDataProviderSource: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}
