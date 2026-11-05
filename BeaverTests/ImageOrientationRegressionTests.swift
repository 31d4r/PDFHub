import BeaverCore
import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import Testing
import UniformTypeIdentifiers

/// A near-square screenshot (1714 × 1692) came out sideways in a converted PDF. A quarter turn
/// barely changes the shape of such an image, so these tests check the content itself: a blue
/// marker drawn in one corner must end up in the right corner of the page and its thumbnail.
@Suite("Image conversion orientation")
struct ImageOrientationRegressionTests {
    /// Where the marker sits on screen.
    enum Corner: Equatable, CustomStringConvertible {
        case topLeft, topRight, bottomLeft, bottomRight

        var description: String {
            switch self {
            case .topLeft: return "top left"
            case .topRight: return "top right"
            case .bottomLeft: return "bottom left"
            case .bottomRight: return "bottom right"
            }
        }
    }

    private static let width = 1714
    private static let height = 1692

    /// White, with a blue quarter in the top-left corner of the stored pixels.
    private static func markedImage(width: Int, height: Int) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        // Core Graphics has y up, so the top of the image is the upper half of the rect.
        context.fill(CGRect(x: 0, y: height / 2, width: width / 2, height: height - height / 2))
        return context.makeImage()!
    }

    private func write(type: UTType, properties: [CFString: Any]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BeaverOrientation-\(UUID().uuidString)")
            .appendingPathExtension(for: type)
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(
            destination,
            Self.markedImage(width: Self.width, height: Self.height),
            properties as CFDictionary
        )
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    /// The corner whose pixel is mostly blue, reading `image` as it appears on screen.
    private func markerCorner(of image: CGImage) throws -> Corner? {
        let side = 32
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let context = try #require(CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        // Row 0 of a bitmap context's memory is the top of the image.
        func isBlue(row: Int, column: Int) -> Bool {
            let offset = (row * side + column) * 4
            return pixels[offset + 2] > 200 && pixels[offset] < 60 && pixels[offset + 1] < 60
        }
        let near = side / 8
        let far = side - 1 - near
        let corners: [(Corner, Bool)] = [
            (.topLeft, isBlue(row: near, column: near)),
            (.topRight, isBlue(row: near, column: far)),
            (.bottomLeft, isBlue(row: far, column: near)),
            (.bottomRight, isBlue(row: far, column: far)),
        ]
        let blue = corners.filter(\.1).map(\.0)
        return blue.count == 1 ? blue.first : nil
    }

    /// Draws `page` as a viewer would, honouring its /Rotate.
    private func render(_ page: CGPDFPage) throws -> CGImage {
        let box = page.getBoxRect(.mediaBox)
        let size = RotationAngle(normalizing: Int(page.rotationAngle)).rotatedSize(box.size)
        let context = try #require(CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.concatenate(page.getDrawingTransform(
            .mediaBox,
            rect: CGRect(origin: .zero, size: size),
            rotate: 0,
            preserveAspectRatio: true
        ))
        context.drawPDFPage(page)
        return try #require(context.makeImage())
    }

    private func convertedPage(_ url: URL, rotation: RotationAngle = .zero) throws -> (URL, CGPDFPage) {
        let result = ImageService().convertImagesToPDF(imageUrls: [url], rotations: [rotation])
        let data = try #require(result.document?.dataRepresentation())
        let pdfURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BeaverOrientation-\(UUID().uuidString).pdf")
        try data.write(to: pdfURL)
        let page = try #require(CGPDFDocument(pdfURL as CFURL)?.page(at: 1))
        return (pdfURL, page)
    }

    // MARK: - No EXIF orientation

    @Test func nearSquarePNGWithoutOrientationStaysUpright() async throws {
        let url = try write(type: .png, properties: [kCGImagePropertyDPIWidth: 144, kCGImagePropertyDPIHeight: 144])
        defer { try? FileManager.default.removeItem(at: url) }
        let (pdfURL, page) = try convertedPage(url)
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        // 1714 × 1692 pixels at 144 dpi is 857 × 846 points, still wider than tall.
        #expect(page.getBoxRect(.mediaBox).size == CGSize(width: 857, height: 846))
        #expect(page.rotationAngle == 0)
        #expect(try markerCorner(of: render(page)) == .topLeft)

        // The page view's thumbnail shows the same thing.
        let thumbnail = try #require(await PDFPageThumbnailer(url: pdfURL).thumbnail(at: 0, maxPixelSize: 200))
        #expect(thumbnail.width > thumbnail.height)
        #expect(try markerCorner(of: thumbnail) == .topLeft)
    }

    @Test func gridPreviewMatchesTheConvertedPage() throws {
        let url = try write(type: .png, properties: [:])
        defer { try? FileManager.default.removeItem(at: url) }
        let service = ImageService()

        let preview = try #require(service.thumbnail(for: url, maxPixelSize: 800))
        #expect(preview.width > preview.height)
        #expect(try markerCorner(of: preview) == .topLeft)
        #expect(service.pixelSize(for: url) == CGSize(width: Self.width, height: Self.height))
    }

    @Test func aRotationOnlyTurnsTheImageItWasMadeFor() throws {
        let first = try write(type: .png, properties: [:])
        let second = try write(type: .png, properties: [:])
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        let result = ImageService().convertImagesToPDF(imageUrls: [first, second], rotations: [.zero, .ninety])
        let document = try #require(result.document)

        #expect(document.page(at: 0)?.bounds(for: .mediaBox).size == CGSize(width: Self.width, height: Self.height))
        #expect(document.page(at: 1)?.bounds(for: .mediaBox).size == CGSize(width: Self.height, height: Self.width))
    }

    @Test func aQuarterTurnMovesTheMarkerClockwise() throws {
        let url = try write(type: .png, properties: [:])
        defer { try? FileManager.default.removeItem(at: url) }
        let (pdfURL, page) = try convertedPage(url, rotation: .ninety)
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        #expect(page.getBoxRect(.mediaBox).size == CGSize(width: Self.height, height: Self.width))
        #expect(try markerCorner(of: render(page)) == .topRight)
    }

    // MARK: - EXIF orientation

    /// Orientation 6 stores the pixels a quarter turn counterclockwise, so the viewer turns them
    /// clockwise: the stored top-left corner shows at the top right, and the image is taller.
    @Test(arguments: [UTType.jpeg, UTType.png])
    func nearSquareImageWithOrientationTagIsTurnedOnce(_ type: UTType) async throws {
        let url = try write(type: type, properties: [kCGImagePropertyOrientation: 6])
        defer { try? FileManager.default.removeItem(at: url) }
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        try #require(
            (properties?[kCGImagePropertyOrientation] as? NSNumber)?.intValue == 6,
            "\(type.identifier) didn't keep the orientation tag"
        )
        let (pdfURL, page) = try convertedPage(url)
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        #expect(page.getBoxRect(.mediaBox).size == CGSize(width: Self.height, height: Self.width))
        #expect(page.rotationAngle == 0)
        #expect(try markerCorner(of: render(page)) == .topRight)

        let preview = try #require(ImageService().thumbnail(for: url, maxPixelSize: 400))
        #expect(try markerCorner(of: preview) == .topRight)
        #expect(ImageService().pixelSize(for: url) == CGSize(width: Self.height, height: Self.width))

        let thumbnail = try #require(await PDFPageThumbnailer(url: pdfURL).thumbnail(at: 0, maxPixelSize: 200))
        #expect(thumbnail.height > thumbnail.width)
        #expect(try markerCorner(of: thumbnail) == .topRight)
    }
}
