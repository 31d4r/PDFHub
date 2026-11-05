import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Writes scanned pages into one PDF, each page as a JPEG sized like paper.
public enum ScanPDFWriter {
    public enum Error: Swift.Error, Equatable {
        case noPages
        case cannotCreate
    }

    /// A page's longest side in points: A4's long edge, so pages print at their real size.
    public static let pageLongSide: CGFloat = 842
    public static let defaultQuality: Double = 0.82

    /// Writes `pages` in order to `url`, replacing any file there.
    public static func write(_ pages: [CGImage], to url: URL, quality: Double = defaultQuality) throws {
        guard !pages.isEmpty else { throw Error.noPages }
        let data = NSMutableData()
        guard
            let consumer = CGDataConsumer(data: data as CFMutableData),
            let context = CGContext(consumer: consumer, mediaBox: nil, nil)
        else { throw Error.cannotCreate }

        for page in pages {
            var box = CGRect(origin: .zero, size: pageSize(for: page))
            let image = jpeg(page, quality: quality) ?? page
            context.beginPage(mediaBox: &box)
            context.interpolationQuality = .high
            context.draw(image, in: box)
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
