import BeaverCore
import CoreGraphics
import CoreText
import Foundation
import PDFKit
import Testing

/// Vision OCR into a searchable PDF. Skips when this Mac/simulator build can't run recognition.
@Suite(.serialized)
struct TextRecognitionTests {
    @Test func searchablePDFContainsTheDrawnWords() async throws {
        try await requireVision()
        let image = try #require(Self.page(text: "Hello Beaver", size: CGSize(width: 600, height: 200)))
        let recognized = try await TextRecognizer.recognize(in: image)
        #expect(recognized.string.lowercased().contains("hello"))
        #expect(recognized.string.lowercased().contains("beaver"))

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BeaverOCR-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try ScanPDFWriter.write([image], text: [recognized], to: url)

        let document = try #require(PDFDocument(url: url))
        let pdfString = try #require(document.string).lowercased()
        #expect(pdfString.contains("hello"))
        #expect(pdfString.contains("beaver"))

        let page = try #require(document.page(at: 0))
        let selection = try #require(document.findString("Beaver", withOptions: .caseInsensitive).first)
        let bounds = selection.bounds(for: page)
        #expect(bounds.width > 10)
        #expect(bounds.height > 5)
        // The selection should sit over the drawn word in the lower-middle of the page.
        #expect(bounds.midY > 20)
        #expect(bounds.midX > 50)
    }

    @Test func rotatedPageKeepsSearchableText() async throws {
        try await requireVision()
        let upright = try #require(Self.page(text: "RotateMe", size: CGSize(width: 400, height: 300)))
        let rotated = try #require(Self.rotate(upright, by: .ninety))
        let recognized = try await TextRecognizer.recognize(in: rotated)
        #expect(recognized.string.lowercased().contains("rotateme") || recognized.string.lowercased().contains("rotate"))

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BeaverOCR-rot-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try ScanPDFWriter.write([rotated], text: [recognized], to: url)
        let document = try #require(PDFDocument(url: url))
        let pdfString = try #require(document.string).lowercased()
        #expect(pdfString.contains("rotate"))
    }

    @Test func emptyPageYieldsNoTextLayer() async throws {
        try await requireVision()
        let blank = ScanImages.make(width: 400, height: 500) { context in
            context.setFillColor(CGColor(gray: 0.95, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 500))
        }
        let recognized = try await TextRecognizer.recognize(in: blank)
        #expect(recognized.isEmpty || recognized.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BeaverOCR-empty-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try ScanPDFWriter.write([blank], text: [recognized], to: url)
        let document = try #require(PDFDocument(url: url))
        let string = document.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        #expect(string.isEmpty)
    }

    @Test func savingWithoutRecognitionLeavesNoText() async throws {
        let image = try #require(Self.page(text: "Secret", size: CGSize(width: 400, height: 120)))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BeaverOCR-off-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try ScanPDFWriter.write([image], text: [], to: url)
        let document = try #require(PDFDocument(url: url))
        let string = document.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        #expect(string.isEmpty)
    }

    // MARK: - Helpers

    private func requireVision() async throws {
        // Vision's accurate path needs a language model; skip cleanly when none are listed.
        let languages = TextRecognizer.availableLanguages()
        try #require(!languages.isEmpty, "Vision text recognition is unavailable in this environment")
    }

    /// White page with black text drawn near the centre.
    private static func page(text: String, size: CGSize) -> CGImage? {
        let width = Int(size.width), height = Int(size.height)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.textMatrix = .identity
        context.setTextDrawingMode(.fill)
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, size.height * 0.35, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CGColor(gray: 0, alpha: 1)
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        var ascent: CGFloat = 0, descent: CGFloat = 0
        let lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        context.textPosition = CGPoint(
            x: (size.width - CGFloat(lineWidth)) / 2,
            y: (size.height - ascent + descent) / 2
        )
        CTLineDraw(line, context)
        return context.makeImage()
    }

    private static func rotate(_ image: CGImage, by rotation: RotationAngle) -> CGImage? {
        let size = CGSize(width: image.width, height: image.height)
        let rotated = rotation.rotatedSize(size)
        guard let context = CGContext(
            data: nil,
            width: Int(rotated.width),
            height: Int(rotated.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.concatenate(rotation.drawingTransform(for: size))
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }
}
