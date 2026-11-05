import BeaverCore
import CoreGraphics
import CoreImage
import Foundation
import Testing

struct PerspectiveCorrectorTests {
    @Test func theWholeImageKeepsItsSize() {
        let image = CIImage(cgImage: ScanImages.make(width: 300, height: 200))
        let corrected = PerspectiveCorrector.correct(image, quad: .fullImage)
        #expect(corrected.extent == CGRect(x: 0, y: 0, width: 300, height: 200))
    }

    @Test func aTiltedPageBecomesARectangleOfItsEdgeLengths() {
        let quad = DocumentQuad(
            topLeft: CGPoint(x: 0.2, y: 0.8),
            topRight: CGPoint(x: 0.7, y: 0.9),
            bottomRight: CGPoint(x: 0.8, y: 0.15),
            bottomLeft: CGPoint(x: 0.1, y: 0.2)
        )
        let size = CGSize(width: 1000, height: 800)
        let image = CIImage(cgImage: ScanImages.make(width: 1000, height: 800))
        let corrected = PerspectiveCorrector.correct(image, quad: quad)
        #expect(corrected.extent.origin == .zero)
        #expect(corrected.extent.size == quad.outputSize(in: size))
    }

    /// Top half red, bottom half blue, cut along a quad given by its corners: the top of the
    /// quad must stay at the top of the page.
    @Test func keepsThePageUpright() throws {
        let image = ScanImages.make(width: 400, height: 600) { context in
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 300, width: 400, height: 300))
            context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        let quad = DocumentQuad(
            topLeft: CGPoint(x: 0.1, y: 0.9),
            topRight: CGPoint(x: 0.9, y: 0.85),
            bottomRight: CGPoint(x: 0.85, y: 0.1),
            bottomLeft: CGPoint(x: 0.15, y: 0.15)
        )
        let page = try #require(ScanImageProcessor().process(image, quad: quad, filter: .original))
        #expect(page.height > page.width)
        let top = ScanImages.pixel(of: page, x: 0.5, y: 0.1)
        let bottom = ScanImages.pixel(of: page, x: 0.5, y: 0.9)
        #expect(top.red > 200 && top.blue < 60)
        #expect(bottom.blue > 200 && bottom.red < 60)
    }

    /// A page lying sideways in the photo, with its top on the right: corners named from the
    /// page's point of view turn it upright.
    @Test func cornersNamedFromThePageTurnIt() throws {
        let image = ScanImages.make(width: 600, height: 400) { context in
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 300, y: 0, width: 300, height: 400))
        }
        let sideways = DocumentQuad(
            topLeft: CGPoint(x: 1, y: 1),
            topRight: CGPoint(x: 1, y: 0),
            bottomRight: CGPoint(x: 0, y: 0),
            bottomLeft: CGPoint(x: 0, y: 1)
        )
        let page = try #require(ScanImageProcessor().process(image, quad: sideways, filter: .original))
        #expect(page.width == 400 && page.height == 600)
        let top = ScanImages.pixel(of: page, x: 0.5, y: 0.1)
        let bottom = ScanImages.pixel(of: page, x: 0.5, y: 0.9)
        #expect(top.red > 200 && top.blue < 60)
        #expect(bottom.brightness > 240)
    }

    @Test func rotationTurnsTheFinishedPage() throws {
        let image = ScanImages.make(width: 300, height: 200)
        let page = try #require(ScanImageProcessor().process(image, filter: .original, rotation: .ninety))
        #expect(page.width == 200 && page.height == 300)
    }
}

struct ScanFilterTests {
    /// Light grey paper darkening towards one side, as under a hand's shadow, with a black mark.
    private func shadowedPage() -> CGImage {
        ScanImages.make(width: 400, height: 500, background: ScanImages.grey(0.75)) { context in
            context.setFillColor(ScanImages.grey(0.5))
            context.fill(CGRect(x: 0, y: 0, width: 140, height: 500))
            context.setFillColor(ScanImages.grey(0.05))
            context.fill(CGRect(x: 240, y: 240, width: 6, height: 40))
            context.fill(CGRect(x: 60, y: 240, width: 6, height: 40))
        }
    }

    @Test(arguments: ScanFilter.allCases)
    func theSameInputGivesTheSamePixels(filter: ScanFilter) throws {
        let processor = ScanImageProcessor()
        let image = shadowedPage()
        let first = try #require(processor.process(image, filter: filter))
        let second = try #require(processor.process(image, filter: filter))
        #expect(first.width == image.width && first.height == image.height)
        #expect(ScanImages.bytes(of: first) == ScanImages.bytes(of: second))
    }

    @Test func enhancedWhitensPaperAndRemovesTheShadow() throws {
        let page = try #require(ScanImageProcessor().process(shadowedPage(), filter: .enhanced))
        let lit = ScanImages.pixel(of: page, x: 0.8, y: 0.2)
        let shadow = ScanImages.pixel(of: page, x: 0.1, y: 0.2)
        let ink = ScanImages.pixel(of: page, x: 241.0 / 400, y: 0.48)
        #expect(lit.brightness > 235)
        #expect(shadow.brightness > 215)
        #expect(ink.brightness < 80)
    }

    @Test func enhancedFindsInkInTheShadowToo() throws {
        let page = try #require(ScanImageProcessor().process(shadowedPage(), filter: .enhanced))
        let ink = ScanImages.pixel(of: page, x: 61.0 / 400, y: 0.48)
        #expect(ink.brightness < 80)
    }

    @Test func grayscaleHasNoColour() throws {
        let image = ScanImages.make(width: 200, height: 200, background: CGColor(red: 0.9, green: 0.8, blue: 0.6, alpha: 1)) { context in
            context.setFillColor(CGColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1))
            context.fill(CGRect(x: 90, y: 90, width: 8, height: 30))
        }
        let page = try #require(ScanImageProcessor().process(image, filter: .grayscale))
        for point in [(0.2, 0.2), (0.47, 0.5)] {
            let pixel = ScanImages.pixel(of: page, x: point.0, y: point.1)
            #expect(abs(pixel.red - pixel.green) <= 2 && abs(pixel.green - pixel.blue) <= 2)
        }
    }

    @Test func blackAndWhiteIsOnlyInkAndPaper() throws {
        let page = try #require(ScanImageProcessor().process(shadowedPage(), filter: .blackAndWhite))
        let values = Set(ScanImages.bytes(of: page).enumerated().filter { $0.offset % 4 == 0 }.map(\.element))
        #expect(values.isSubset(of: [0, 255]))
        #expect(ScanImages.pixel(of: page, x: 0.1, y: 0.2).brightness == 255)
        #expect(ScanImages.pixel(of: page, x: 61.0 / 400, y: 0.48).brightness == 0)
    }
}

struct ScanPDFWriterTests {
    @Test func writesOnePageAPaperSizedPerImage() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        let portrait = ScanImages.make(width: 1240, height: 1754)
        let landscape = ScanImages.make(width: 1600, height: 1200)
        try ScanPDFWriter.write([portrait, landscape], to: url)

        let document = try #require(CGPDFDocument(url as CFURL))
        #expect(document.numberOfPages == 2)
        let first = try #require(document.page(at: 1)).getBoxRect(.mediaBox)
        let second = try #require(document.page(at: 2)).getBoxRect(.mediaBox)
        #expect(first.height == ScanPDFWriter.pageLongSide && first.width == 595)
        #expect(second.width == ScanPDFWriter.pageLongSide && second.height == 632)
    }

    @Test func refusesAnEmptyScan() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
        #expect(throws: ScanPDFWriter.Error.noPages) {
            try ScanPDFWriter.write([], to: url)
        }
    }

    @Test func buildsAPDFFromStoredPages() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let builder = ScanDocumentBuilder(directory: directory)
        let stored = try builder.store(ScanImages.make(width: 4000, height: 3000))
        let page = ScanPage(imageURL: stored, filter: .grayscale, rotation: .ninety)
        let image = try #require(builder.render(page))
        #expect(image.width == 2400 && image.height == 3200)

        let url = directory.appendingPathComponent("Scan.pdf")
        try await builder.writePDF([page, ScanPage(imageURL: stored)], to: url)
        #expect(CGPDFDocument(url as CFURL)?.numberOfPages == 2)

        builder.discard([page])
        #expect(!FileManager.default.fileExists(atPath: stored.path))
    }

    @Test func previewMatchesThePageShapeAtASmallerSize() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let builder = ScanDocumentBuilder(directory: directory)
        let stored = try builder.store(ScanImages.make(width: 4000, height: 3000))
        let page = ScanPage(imageURL: stored, filter: .blackAndWhite, rotation: .ninety)
        let preview = try #require(builder.preview(page, maxPixelSize: 400))
        #expect(preview.width == 300 && preview.height == 400)
    }
}

struct ScanFileNameTests {
    @Test func namesTheScanByDateAndMinute() throws {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "Europe/Vienna")
        (components.year, components.month, components.day, components.hour, components.minute) = (2026, 11, 4, 17, 5)
        let date = try #require(components.date)
        let name = ScanFileName.make(prefix: "Scan", date: date, timeZone: TimeZone(identifier: "Europe/Vienna")!)
        #expect(name == "Scan 2026-11-04 17.05")
    }

    @Test(arguments: [
        ("Receipts/Nov", "Receipts-Nov"),
        ("  Lease.pdf ", "Lease"),
        ("10:30 notes", "10.30 notes"),
        (".hidden", "hidden")
    ])
    func cleansTypedNames(input: String, expected: String) {
        #expect(ScanFileName.sanitized(input) == expected)
    }

    @Test func anEmptyNameIsRefused() {
        #expect(ScanFileName.sanitized("   ") == nil)
        #expect(ScanFileName.sanitized(".pdf") == nil)
    }
}
