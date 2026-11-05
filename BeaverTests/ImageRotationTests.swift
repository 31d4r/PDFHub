import BeaverCore
import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import Testing
import UniformTypeIdentifiers
@testable import Beaver

/// Which half of a two-colour test image a sampled pixel came from.
enum Swatch: Equatable {
    case red
    case blue
}

enum RotationImages {
    /// Left half red, right half blue, so every quarter turn is distinguishable.
    static func split(width: Int, height: Int) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        return context.makeImage()!
    }

    /// The swatch at a point given as fractions of the width and height, measured from the top left.
    static func swatch(of image: CGImage, x: Double, y: Double) -> Swatch? {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        // Row 0 of a bitmap context's memory is the top of the image.
        let column = min(width - 1, Int(Double(width) * x))
        let row = min(height - 1, Int(Double(height) * y))
        let offset = (row * width + column) * 4
        let red = Int(pixels[offset])
        let blue = Int(pixels[offset + 2])
        if red > 150 && blue < 100 { return .red }
        if blue > 150 && red < 100 { return .blue }
        return nil
    }

    /// Renders a PDF page as it would be displayed, honouring its /Rotate.
    static func render(_ page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let rotation = RotationAngle(normalizing: page.rotation)
        let size = rotation.rotatedSize(bounds.size)
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        page.draw(with: .mediaBox, to: context)
        return context.makeImage()
    }

    static func write(_ image: CGImage, type: UTType, properties: [CFString: Any] = [:]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BeaverRotation-\(UUID().uuidString)")
            .appendingPathExtension(for: type)
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }
}

struct RotationGeometryTests {
    @Test func quarterTurnsSwapTheSize() {
        let size = CGSize(width: 200, height: 100)
        #expect(RotationAngle.zero.rotatedSize(size) == size)
        #expect(RotationAngle.ninety.rotatedSize(size) == CGSize(width: 100, height: 200))
        #expect(RotationAngle.oneEighty.rotatedSize(size) == size)
        #expect(RotationAngle.twoSeventy.rotatedSize(size) == CGSize(width: 100, height: 200))
    }

    @Test(arguments: RotationAngle.allCases)
    func transformFillsTheRotatedRect(angle: RotationAngle) {
        let size = CGSize(width: 200, height: 100)
        let mapped = CGRect(origin: .zero, size: size).applying(angle.drawingTransform(for: size))
        #expect(mapped.integral == CGRect(origin: .zero, size: angle.rotatedSize(size)))
    }

    @Test func clockwiseNinetyMovesTheTopLeftCornerToTheTopRight() {
        // In y-up coordinates the top-left corner of a 200×100 rect is (0, 100).
        let size = CGSize(width: 200, height: 100)
        let point = CGPoint(x: 0, y: 100).applying(RotationAngle.ninety.drawingTransform(for: size))
        #expect(point == CGPoint(x: 100, y: 200))
    }

    @Test func normalizingAndAdding() {
        #expect(RotationAngle(normalizing: -90) == .twoSeventy)
        #expect(RotationAngle(normalizing: 450) == .ninety)
        #expect(RotationAngle(normalizing: 720) == .zero)
        #expect(RotationAngle.twoSeventy.adding(.oneEighty) == .ninety)
    }
}

struct ImageRotatorTests {
    private let image = RotationImages.split(width: 20, height: 10)

    @Test func zeroReturnsTheSameImage() {
        #expect(ImageRotator.rotate(image, by: .zero) === image)
    }

    @Test func rightTurnPutsTheLeftEdgeOnTop() throws {
        let rotated = try #require(ImageRotator.rotate(image, by: .ninety))
        #expect(rotated.width == 10 && rotated.height == 20)
        #expect(RotationImages.swatch(of: rotated, x: 0.5, y: 0.25) == .red)
        #expect(RotationImages.swatch(of: rotated, x: 0.5, y: 0.75) == .blue)
    }

    @Test func halfTurnSwapsLeftAndRight() throws {
        let rotated = try #require(ImageRotator.rotate(image, by: .oneEighty))
        #expect(rotated.width == 20 && rotated.height == 10)
        #expect(RotationImages.swatch(of: rotated, x: 0.25, y: 0.5) == .blue)
        #expect(RotationImages.swatch(of: rotated, x: 0.75, y: 0.5) == .red)
    }

    @Test func leftTurnPutsTheRightEdgeOnTop() throws {
        let rotated = try #require(ImageRotator.rotate(image, by: .twoSeventy))
        #expect(rotated.width == 10 && rotated.height == 20)
        #expect(RotationImages.swatch(of: rotated, x: 0.5, y: 0.25) == .blue)
        #expect(RotationImages.swatch(of: rotated, x: 0.5, y: 0.75) == .red)
    }
}

struct ImageItemRotationTests {
    @Test func rotatingRedrawsThePreview() {
        var item = ImageItem(url: URL(fileURLWithPath: "/tmp/a.png"), thumbnail: TestImages.solid(width: 40, height: 20))
        #expect(item.preview.width == 40)

        item.rotate(.right)
        #expect(item.rotationAngle == .ninety)
        #expect(item.preview.width == 20 && item.preview.height == 40)
        #expect(item.thumbnail.width == 40)

        item.rotate(.left)
        #expect(item.rotationAngle == .zero)
        #expect(item.preview.width == 40 && item.preview.height == 20)
    }

    @Test func equalityIncludesRotation() {
        let item = ImageItem(url: URL(fileURLWithPath: "/tmp/a.png"), thumbnail: TestImages.solid(width: 4, height: 4))
        var rotated = item
        rotated.rotate(.left)
        #expect(item != rotated)
        #expect(rotated.rotationAngle == .twoSeventy)
    }
}

struct ImageConversionRotationTests {
    private func firstPage(_ result: ImageConversionResult) throws -> PDFPage {
        try #require(result.document?.page(at: 0))
    }

    @Test(arguments: [
        (RotationAngle.zero, CGSize(width: 200, height: 100)),
        (.ninety, CGSize(width: 100, height: 200)),
        (.oneEighty, CGSize(width: 200, height: 100)),
        (.twoSeventy, CGSize(width: 100, height: 200)),
    ])
    func rotationSetsThePageSize(angle: RotationAngle, expected: CGSize) throws {
        let url = try RotationImages.write(RotationImages.split(width: 200, height: 100), type: .png)
        defer { try? FileManager.default.removeItem(at: url) }

        let page = try firstPage(ImageService().convertImagesToPDF(imageUrls: [url], rotations: [angle]))

        #expect(page.bounds(for: .mediaBox).size == expected)
        // Baked into the content, not left to the viewer.
        #expect(page.rotation == 0)
    }

    @Test func rightTurnIsBakedIntoTheContent() throws {
        let url = try RotationImages.write(RotationImages.split(width: 200, height: 100), type: .png)
        defer { try? FileManager.default.removeItem(at: url) }

        let page = try firstPage(ImageService().convertImagesToPDF(imageUrls: [url], rotations: [.ninety]))
        let rendered = try #require(RotationImages.render(page))

        #expect(RotationImages.swatch(of: rendered, x: 0.5, y: 0.25) == .red)
        #expect(RotationImages.swatch(of: rendered, x: 0.5, y: 0.75) == .blue)
    }

    @Test func composesWithExifOrientation() throws {
        // Orientation 6 already turns the stored pixels 90° clockwise for display;
        // a further right turn makes 180° in total.
        let url = try RotationImages.write(
            RotationImages.split(width: 200, height: 100),
            type: .jpeg,
            properties: [kCGImagePropertyOrientation: 6]
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let upright = try firstPage(ImageService().convertImagesToPDF(imageUrls: [url], rotations: [.zero]))
        #expect(upright.bounds(for: .mediaBox).size == CGSize(width: 100, height: 200))
        let uprightImage = try #require(RotationImages.render(upright))
        #expect(RotationImages.swatch(of: uprightImage, x: 0.5, y: 0.25) == .red)

        let turned = try firstPage(ImageService().convertImagesToPDF(imageUrls: [url], rotations: [.ninety]))
        #expect(turned.bounds(for: .mediaBox).size == CGSize(width: 200, height: 100))
        let turnedImage = try #require(RotationImages.render(turned))
        #expect(RotationImages.swatch(of: turnedImage, x: 0.25, y: 0.5) == .blue)
        #expect(RotationImages.swatch(of: turnedImage, x: 0.75, y: 0.5) == .red)
    }

    @Test func rotationsMatchByPosition() throws {
        let wide = try RotationImages.write(RotationImages.split(width: 40, height: 20), type: .png)
        let missing = URL(fileURLWithPath: "/tmp/beaver-missing-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: wide) }

        let result = ImageService().convertImagesToPDF(
            imageUrls: [wide, missing, wide],
            rotations: [.ninety, .oneEighty]
        )

        let document = try #require(result.document)
        #expect(document.pageCount == 2)
        #expect(document.page(at: 0)?.bounds(for: .mediaBox).size == CGSize(width: 20, height: 40))
        // The third image has no entry, so it stays as it is.
        #expect(document.page(at: 1)?.bounds(for: .mediaBox).size == CGSize(width: 40, height: 20))
        #expect(result.skippedURLs == [missing])
    }
}

@MainActor
struct ReactorImageRotationTests {
    private let destination = URL(fileURLWithPath: "/tmp/beaver-rotation-test.pdf")
    private let urls = (1...2).map { URL(fileURLWithPath: "/tmp/beaver-rotate-\($0).png") }

    private func makeReactor(export: MockExportService = MockExportService()) async -> BeaverReactor {
        let images = MockImageService()
        for url in urls {
            images.thumbnailsByURL[url] = TestImages.solid(width: 40, height: 20)
        }
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let reactor = BeaverReactor(saveLocationProvider: panels, imageService: images, exportService: export)
        await reactor.action(.addImages(urls))
        return reactor
    }

    @Test func rotatesOnlyTheChosenImage() async {
        let reactor = await makeReactor()
        let first = reactor.state.selectedImages[0]

        reactor.action(.rotateImage(id: first.id, direction: .right))
        reactor.action(.rotateImage(id: first.id, direction: .right))
        reactor.action(.rotateImage(id: UUID(), direction: .right))

        #expect(reactor.state.selectedImages.map(\.rotationAngle) == [.oneEighty, .zero])
    }

    @Test func convertSendsRotationsInListOrder() async {
        let export = MockExportService()
        let reactor = await makeReactor(export: export)
        let second = reactor.state.selectedImages[1]

        reactor.action(.rotateImage(id: second.id, direction: .left))
        reactor.action(.moveImage(id: second.id, to: 0))
        await reactor.action(.convertImagesToPDF)

        #expect(export.calls == [.convert(urls: [urls[1], urls[0]], rotations: [.twoSeventy, .zero], destination: destination)])
    }

    @Test func rotationIsIgnoredWhileConverting() async {
        let export = MockExportService(isGated: true)
        let reactor = await makeReactor(export: export)

        let running = Task { await reactor.action(.convertImagesToPDF) }
        while reactor.state.activity == nil {
            await Task.yield()
        }
        reactor.action(.rotateImage(id: reactor.state.selectedImages[0].id, direction: .right))
        #expect(reactor.state.selectedImages.map(\.rotationAngle) == [.zero, .zero])

        export.release()
        await running.value
    }

    @Test func discardMentionsImageRotations() async {
        let reactor = await makeReactor()
        #expect(!reactor.state.hasDiscardableRotations)
        reactor.action(.rotateImage(id: reactor.state.selectedImages[0].id, direction: .right))
        #expect(reactor.state.hasDiscardableRotations)
    }
}
