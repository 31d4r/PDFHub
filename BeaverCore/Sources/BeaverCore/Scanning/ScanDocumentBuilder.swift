import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Stores scanned photos and builds the finished PDF from reviewed pages.
public struct ScanDocumentBuilder: Sendable {
    public enum Error: Swift.Error, Equatable {
        case unreadablePage
        case cannotSaveImage
    }

    private let processor: ScanImageProcessor
    private let imageService: ImageService
    /// Where photos wait while they are reviewed.
    public let directory: URL

    public init(
        directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("Scans", isDirectory: true),
        processor: ScanImageProcessor = ScanImageProcessor()
    ) {
        self.directory = directory
        self.processor = processor
        self.imageService = ImageService()
    }

    /// Saves a captured photo, upright and no larger than the processor needs, for review.
    public func store(_ image: CGImage) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
        let scaled = Self.downscaled(image, maxPixelSize: ScanImageProcessor.maximumPixelSize)
        guard
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw Error.cannotSaveImage }
        CGImageDestinationAddImage(destination, scaled, [
            kCGImageDestinationLossyCompressionQuality: Constants.storedQuality
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Error.cannotSaveImage }
        return url
    }

    /// An image file, such as a photo from the library, upright by its EXIF orientation.
    public func loadImage(at url: URL, maxPixelSize: Int = ScanImageProcessor.maximumPixelSize) -> CGImage? {
        imageService.thumbnail(for: url, maxPixelSize: maxPixelSize)
    }

    /// The page as it will appear in the PDF.
    public func render(_ page: ScanPage) -> CGImage? {
        guard let image = loadImage(at: page.imageURL) else { return nil }
        return processor.process(image, quad: page.quad, filter: page.filter, rotation: page.rotation)
    }

    /// A smaller copy of the finished page for the review screen. It is cut, filtered and
    /// turned the same way as the PDF page, from a smaller copy of the photo.
    public func preview(_ page: ScanPage, maxPixelSize: Int) -> CGImage? {
        guard let image = loadImage(at: page.imageURL, maxPixelSize: maxPixelSize) else { return nil }
        return processor.process(image, quad: page.quad, filter: page.filter, rotation: page.rotation)
    }

    /// Writes every page, in order, into one PDF at `url`. Stops early when the task is cancelled.
    /// When `recognizeText` is true, each page gets an invisible searchable text layer.
    /// `onProgress` reports 0…1 across render + recognition of every page.
    public func writePDF(
        _ pages: [ScanPage],
        to url: URL,
        recognizeText: Bool = true,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        var images: [CGImage] = []
        var text: [RecognizedText?] = []
        let total = max(pages.count, 1)
        for (index, page) in pages.enumerated() {
            try Task.checkCancellation()
            guard let image = render(page) else { throw Error.unreadablePage }
            images.append(image)
            if recognizeText {
                let base = Double(index) / Double(total)
                let span = 1 / Double(total)
                let recognized = try await TextRecognizer.recognize(in: image) { fraction in
                    onProgress?(base + fraction * span * 0.9)
                }
                text.append(recognized)
            } else {
                text.append(nil)
            }
            onProgress?(Double(index + 1) / Double(total))
        }
        try ScanPDFWriter.write(images, text: recognizeText ? text : [], to: url)
    }

    /// Deletes stored photos once the scan is saved or discarded.
    public func discard(_ pages: [ScanPage]) {
        for page in pages where page.imageURL.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL {
            try? FileManager.default.removeItem(at: page.imageURL)
        }
    }

    static func downscaled(_ image: CGImage, maxPixelSize: Int) -> CGImage {
        let longest = max(image.width, image.height)
        guard longest > maxPixelSize else { return image }
        let scale = Double(maxPixelSize) / Double(longest)
        let width = Int((Double(image.width) * scale).rounded())
        let height = Int((Double(image.height) * scale).rounded())
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }
}

private enum Constants {
    static let storedQuality: Double = 0.9
}
