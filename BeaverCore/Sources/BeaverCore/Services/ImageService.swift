import CoreGraphics
import Foundation
import ImageIO
import PDFKit

public protocol ImageServiceProtocol: Sendable {
    /// A preview no larger than `maxPixelSize` on its longest side, with EXIF
    /// orientation applied. `nil` when the file is not a readable image.
    func thumbnail(for url: URL, maxPixelSize: Int) -> CGImage?
    /// One page per readable image, in order. `rotations[i]` turns `imageUrls[i]` clockwise on top of
    /// its EXIF orientation, and quarter turns swap the page size. Matched by position, so the same
    /// file added twice can be turned two ways; missing entries mean no rotation.
    func convertImagesToPDF(imageUrls: [URL], rotations: [RotationAngle]) -> ImageConversionResult
    /// Like `convertImagesToPDF(imageUrls:rotations:)`, and when `recognizeText` is true each page
    /// gets an invisible searchable text layer from Vision.
    func convertImagesToPDF(
        imageUrls: [URL],
        rotations: [RotationAngle],
        recognizeText: Bool
    ) async -> ImageConversionResult
    /// The image's size in pixels, upright by its EXIF orientation. `nil` when it can't be read.
    func pixelSize(for url: URL) -> CGSize?
}

public extension ImageServiceProtocol {
    func pixelSize(for url: URL) -> CGSize? { nil }

    func convertImagesToPDF(imageUrls: [URL]) -> ImageConversionResult {
        convertImagesToPDF(imageUrls: imageUrls, rotations: [])
    }

    func convertImagesToPDF(
        imageUrls: [URL],
        rotations: [RotationAngle],
        recognizeText: Bool
    ) async -> ImageConversionResult {
        // Mocks and callers that skip OCR keep the synchronous path.
        _ = recognizeText
        return convertImagesToPDF(imageUrls: imageUrls, rotations: rotations)
    }
}

public struct ImageConversionResult {
    /// `nil` when none of the images could be converted.
    public let document: PDFDocument?
    /// Images that could not be read and were left out.
    public let skippedURLs: [URL]

    public init(document: PDFDocument?, skippedURLs: [URL]) {
        self.document = document
        self.skippedURLs = skippedURLs
    }
}

/// Reads images with ImageIO and draws PDFs with Core Graphics, so it works on
/// macOS and iOS without AppKit or UIKit.
public struct ImageService: ImageServiceProtocol {
    public init() {}

    public func thumbnail(for url: URL, maxPixelSize: Int) -> CGImage? {
        guard let source = makeSource(for: url) else { return nil }
        return orientedImage(from: source, maxPixelSize: maxPixelSize)
    }

    public func pixelSize(for url: URL) -> CGSize? {
        guard
            let source = makeSource(for: url),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
            let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
            width > 0, height > 0
        else { return nil }
        // EXIF orientations 5–8 store the image turned a quarter.
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        return (5...8).contains(orientation)
            ? CGSize(width: height, height: width)
            : CGSize(width: width, height: height)
    }

    public func convertImagesToPDF(imageUrls: [URL], rotations: [RotationAngle]) -> ImageConversionResult {
        convertSync(imageUrls: imageUrls, rotations: rotations, text: nil)
    }

    public func convertImagesToPDF(
        imageUrls: [URL],
        rotations: [RotationAngle],
        recognizeText: Bool
    ) async -> ImageConversionResult {
        guard recognizeText else {
            return convertImagesToPDF(imageUrls: imageUrls, rotations: rotations)
        }
        // One RecognizedText per readable page, in the same order convertSync draws them.
        var texts: [RecognizedText?] = []
        for (index, imageUrl) in imageUrls.enumerated() {
            try? Task.checkCancellation()
            guard let page = fullSizePage(for: imageUrl) else { continue }
            let rotation = rotations.indices.contains(index) ? rotations[index] : .zero
            let imageForOCR = Self.rotatedPixelImage(page.image, by: rotation) ?? page.image
            let recognized = (try? await TextRecognizer.recognize(in: imageForOCR)) ?? RecognizedText(runs: [])
            texts.append(recognized)
        }
        return convertSync(imageUrls: imageUrls, rotations: rotations, text: texts)
    }

    private func convertSync(
        imageUrls: [URL],
        rotations: [RotationAngle],
        text: [RecognizedText?]?
    ) -> ImageConversionResult {
        let data = NSMutableData()
        var skippedURLs: [URL] = []
        var pageCount = 0
        var textIndex = 0

        guard
            let consumer = CGDataConsumer(data: data as CFMutableData),
            let context = CGContext(consumer: consumer, mediaBox: nil, nil)
        else {
            return ImageConversionResult(document: nil, skippedURLs: imageUrls)
        }

        for (index, imageUrl) in imageUrls.enumerated() {
            guard let page = fullSizePage(for: imageUrl) else {
                skippedURLs.append(imageUrl)
                continue
            }

            let rotation = rotations.indices.contains(index) ? rotations[index] : .zero
            var mediaBox = CGRect(origin: .zero, size: rotation.rotatedSize(page.size))
            let pageInfo = [kCGPDFContextMediaBox as String: Data(
                bytes: &mediaBox,
                count: MemoryLayout<CGRect>.size
            )] as CFDictionary
            context.beginPDFPage(pageInfo)
            context.saveGState()
            context.concatenate(rotation.drawingTransform(for: page.size))
            context.draw(page.image, in: CGRect(origin: .zero, size: page.size))
            context.restoreGState()
            if let text, text.indices.contains(textIndex), let recognized = text[textIndex], !recognized.isEmpty {
                ScanPDFWriter.drawInvisibleText(recognized, in: mediaBox, context: context)
            }
            textIndex += 1
            context.endPDFPage()
            pageCount += 1
        }
        context.closePDF()

        let document = pageCount > 0 ? PDFDocument(data: data as Data) : nil
        return ImageConversionResult(document: document, skippedURLs: skippedURLs)
    }

    /// Pixels turned the same way the PDF page is, so Vision's boxes match the media box.
    private static func rotatedPixelImage(_ image: CGImage, by rotation: RotationAngle) -> CGImage? {
        guard rotation != .zero else { return image }
        let size = CGSize(width: image.width, height: image.height)
        let rotated = rotation.rotatedSize(size)
        let width = Int(rotated.width.rounded())
        let height = Int(rotated.height.rounded())
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.concatenate(rotation.drawingTransform(for: size))
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }

    // MARK: - Private

    private struct Page {
        let image: CGImage
        /// Page size in points, from the image's pixel size and resolution.
        let size: CGSize
    }

    private func makeSource(for url: URL) -> CGImageSource? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        return CGImageSourceCreateWithURL(url as CFURL, options)
    }

    /// The first frame, rotated by its EXIF orientation and at most `maxPixelSize` on its longest side.
    private func orientedImage(from source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    private func fullSizePage(for url: URL) -> Page? {
        guard
            let source = makeSource(for: url),
            CGImageSourceGetCount(source) > 0,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let pixelWidth = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
            let pixelHeight = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
            pixelWidth > 0, pixelHeight > 0,
            let image = orientedImage(from: source, maxPixelSize: max(pixelWidth, pixelHeight))
        else {
            return nil
        }

        let dpiWidth = Self.resolution(properties[kCGImagePropertyDPIWidth])
        let dpiHeight = Self.resolution(properties[kCGImagePropertyDPIHeight])
        // The DPI values describe the stored pixels, so swap them when EXIF orientation turned the image.
        let isQuarterTurned = image.width == pixelHeight && image.height == pixelWidth && pixelWidth != pixelHeight
        let (horizontalDPI, verticalDPI) = isQuarterTurned ? (dpiHeight, dpiWidth) : (dpiWidth, dpiHeight)
        let size = CGSize(
            width: CGFloat(image.width) * Self.pointsPerInch / horizontalDPI,
            height: CGFloat(image.height) * Self.pointsPerInch / verticalDPI
        )
        return Page(image: image, size: size)
    }

    private static let pointsPerInch: CGFloat = 72

    /// Treats a missing or invalid resolution as 72 dpi, like AppKit does.
    private static func resolution(_ value: Any?) -> CGFloat {
        guard let dpi = (value as? NSNumber)?.doubleValue, dpi > 0 else { return pointsPerInch }
        return CGFloat(dpi)
    }
}
