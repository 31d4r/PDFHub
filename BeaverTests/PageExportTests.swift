import BeaverCore
import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import Testing
@testable import Beaver

/// PDFs made for these tests: page `i` is `200 + 10 i` points wide and 100 tall, with a red
/// square in its top-left corner, so a page can be told apart by its width and its rotation
/// by where the square ends up.
enum PageExportFixtures {
    static func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("beaver-page-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func width(ofPage index: Int) -> CGFloat { 200 + CGFloat(index) * 10 }

    @discardableResult
    static func makePDF(pages: Int, named name: String = "report.pdf", in folder: URL) -> URL {
        let url = folder.appendingPathComponent(name)
        let context = CGContext(url as CFURL, mediaBox: nil, nil)!
        for index in 0..<pages {
            var box = CGRect(x: 0, y: 0, width: width(ofPage: index), height: 100)
            context.beginPage(mediaBox: &box)
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 80, width: 20, height: 20))
            context.endPage()
        }
        context.closePDF()
        return url
    }

    static func makeLockedPDF(in folder: URL) throws -> URL {
        let source = makePDF(pages: 2, named: "open.pdf", in: folder)
        let url = folder.appendingPathComponent("locked.pdf")
        let document = try #require(PDFDocument(url: source))
        let written = document.write(to: url, withOptions: [
            .userPasswordOption: "secret",
            .ownerPasswordOption: "owner",
        ])
        #expect(written)
        return url
    }

    static func imageSource(_ data: Data) throws -> CGImageSource {
        try #require(CGImageSourceCreateWithData(data as CFData, nil))
    }

    static func image(_ data: Data) throws -> CGImage {
        try #require(CGImageSourceCreateImageAtIndex(try imageSource(data), 0, nil))
    }

    /// Whether the pixel at (`x`, `y`), counted from the top-left, is red.
    static func isRed(_ image: CGImage, x: Int, y: Int) -> Bool {
        let context = CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        // Shift the image so the wanted pixel lands on the 1 × 1 bitmap (y up).
        context.draw(image, in: CGRect(
            x: -CGFloat(x), y: -CGFloat(image.height - 1 - y),
            width: CGFloat(image.width), height: CGFloat(image.height)
        ))
        let pixel = context.data!.assumingMemoryBound(to: UInt8.self)
        return pixel[0] > 200 && pixel[1] < 60 && pixel[2] < 60
    }
}

// MARK: - Extracting pages as a PDF

struct PDFPageExtractionTests {
    private let exporter = PDFPageExporter()

    @Test func extractsOnePageAsItsOwnPDF() throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = PageExportFixtures.makePDF(pages: 3, in: folder)

        let document = try exporter.extractPDF(PageExportSource(url: url, pages: [1]))

        #expect(document.pageCount == 1)
        #expect(document.page(at: 0)?.bounds(for: .cropBox).width == PageExportFixtures.width(ofPage: 1))
    }

    @Test func extractsSeveralPagesInTheOrderGiven() throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = PageExportFixtures.makePDF(pages: 4, in: folder)

        let document = try exporter.extractPDF(PageExportSource(url: url, pages: [3, 0, 2]))

        let widths = (0..<document.pageCount).compactMap { document.page(at: $0)?.bounds(for: .cropBox).width }
        #expect(widths == [3, 0, 2].map(PageExportFixtures.width(ofPage:)))
    }

    @Test func extractsTheOnlyPageOfASinglePagePDF() throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = PageExportFixtures.makePDF(pages: 1, in: folder)

        #expect(try exporter.extractPDF(PageExportSource(url: url)).pageCount == 1)
        #expect(try exporter.extractPDF(PageExportSource(url: url, pages: [0])).pageCount == 1)
    }

    @Test func leavesOutRepeatsAndPagesOutsideTheDocument() throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = PageExportFixtures.makePDF(pages: 2, in: folder)

        let document = try exporter.extractPDF(PageExportSource(url: url, pages: [1, 1, 7, -1]))

        #expect(document.pageCount == 1)
        #expect(try exporter.pageCount(of: PageExportSource(url: url, pages: [1, 1, 7])) == 1)
    }

    @Test func appliesFileAndPageRotationsWithoutChangingTheSource() throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = PageExportFixtures.makePDF(pages: 2, in: folder)
        let rotation = PDFRotation(file: .ninety, pages: [1: .ninety])

        let document = try exporter.extractPDF(PageExportSource(url: url, rotation: rotation, pages: [0, 1]))

        #expect(document.page(at: 0)?.rotation == 90)
        #expect(document.page(at: 1)?.rotation == 180)
        #expect(PDFDocument(url: url)?.page(at: 1)?.rotation == 0)
    }

    @Test func passwordProtectedPDFsAreReportedAsLocked() throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try PageExportFixtures.makeLockedPDF(in: folder)

        #expect(throws: PageExportError.locked(url)) {
            try exporter.extractPDF(PageExportSource(url: url))
        }
    }

    @Test func filesThatAreNotPDFsAreUnreadable() {
        let image = TestFixtures.samplePNG
        let missing = URL(fileURLWithPath: "/tmp/beaver-missing-\(UUID().uuidString).pdf")

        #expect(throws: PageExportError.unreadable(image)) {
            try exporter.extractPDF(PageExportSource(url: image))
        }
        #expect(throws: PageExportError.unreadable(missing)) {
            try exporter.pageCount(of: PageExportSource(url: missing))
        }
    }

    @Test func choosingNoPagesHasNothingToExport() throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = PageExportFixtures.makePDF(pages: 2, in: folder)

        #expect(throws: PageExportError.noPages(url)) {
            try exporter.extractPDF(PageExportSource(url: url, pages: []))
        }
        #expect(throws: PageExportError.noPages(url)) {
            try exporter.pageCount(of: PageExportSource(url: url, pages: [5]))
        }
    }

    @Test func pageIndexesKeepOrderAndDropRepeats() {
        #expect(PDFPageExporter.pageIndexes(nil, pageCount: 3) == [0, 1, 2])
        #expect(PDFPageExporter.pageIndexes([2, 0, 2, 9], pageCount: 3) == [2, 0])
        #expect(PDFPageExporter.pageIndexes(nil, pageCount: 0).isEmpty)
    }
}

// MARK: - Drawing pages as images

struct PDFPageImageTests {
    private let exporter = PDFPageExporter()

    private func firstPage(of url: URL, rotation: PDFRotation = .none) throws -> PDFPage {
        try exporter.prepare(PageExportSource(url: url, rotation: rotation, pages: [0])).pages[0].page
    }

    @Test func rendersAPageAsAPNGAt200PixelsPerInch() throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = PageExportFixtures.makePDF(pages: 1, in: folder)

        let data = try #require(exporter.imageData(for: try firstPage(of: url), format: .png))

        #expect(!data.isEmpty)
        let source = try PageExportFixtures.imageSource(data)
        #expect(CGImageSourceGetType(source) as String? == "public.png")
        let image = try PageExportFixtures.image(data)
        // 200 × 100 points at 200 / 72.
        #expect(image.width == 556)
        #expect(image.height == 278)
        #expect(PageExportFixtures.isRed(image, x: 10, y: 10))
        #expect(!PageExportFixtures.isRed(image, x: image.width - 10, y: image.height - 10))
    }

    @Test func rendersAPageAsAJPEG() throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = PageExportFixtures.makePDF(pages: 1, in: folder)

        let data = try #require(exporter.imageData(for: try firstPage(of: url), format: .jpeg))

        let source = try PageExportFixtures.imageSource(data)
        #expect(CGImageSourceGetType(source) as String? == "public.jpeg")
        #expect(Array(data.prefix(2)) == [0xFF, 0xD8])
        #expect(try PageExportFixtures.image(data).width == 556)
    }

    @Test func turnedPagesAreDrawnTurned() throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = PageExportFixtures.makePDF(pages: 1, in: folder)

        let data = try #require(exporter.imageData(
            for: try firstPage(of: url, rotation: PDFRotation(file: .ninety)),
            format: .png
        ))

        let image = try PageExportFixtures.image(data)
        #expect(image.width == 278)
        #expect(image.height == 556)
        // A quarter turn clockwise moves the top-left square to the top-right.
        #expect(PageExportFixtures.isRed(image, x: image.width - 10, y: 10))
        #expect(!PageExportFixtures.isRed(image, x: 10, y: 10))
    }

    @Test func pdfIsNotAnImageFormat() throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = PageExportFixtures.makePDF(pages: 1, in: folder)

        #expect(exporter.imageData(for: try firstPage(of: url), format: .pdf) == nil)
    }

    @Test func hugePagesAreScaledToTheMaximumSize() throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("poster.pdf")
        var box = CGRect(x: 0, y: 0, width: 7_200, height: 3_600)
        let context = try #require(CGContext(url as CFURL, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        context.endPDFPage()
        context.closePDF()

        let image = try #require(PDFPageExporter.render(try firstPage(of: url)))

        #expect(CGFloat(image.width) == PDFPageExporter.maxPixelDimension)
        #expect(image.height == 4_000)
    }
}

// MARK: - File names

struct PageExportNamingTests {
    private let source = URL(fileURLWithPath: "/tmp/Quarterly Report.pdf")

    @Test func imageNamesFollowSplit() {
        #expect(PDFPageExporter.imageFileName(sourceURL: source, pageIndex: 1, format: .png) == "Quarterly Report_page-2.png")
        #expect(PDFPageExporter.imageFileName(sourceURL: source, pageIndex: 0, format: .jpeg) == "Quarterly Report_page-1.jpg")
    }

    @Test func pdfNamesDescribeThePages() {
        #expect(PDFPageExporter.pdfFileName(sourceURL: source, pages: [2]) == "Quarterly Report_page-3.pdf")
        #expect(PDFPageExporter.pdfFileName(sourceURL: source, pages: [1, 2, 3]) == "Quarterly Report_pages-2-4.pdf")
        #expect(PDFPageExporter.pdfFileName(sourceURL: source, pages: [0, 4]) == "Quarterly Report_pages.pdf")
        #expect(PDFPageExporter.pdfFileName(sourceURL: source, pages: []) == "Quarterly Report_pages.pdf")
    }

    @Test func imageFolderIsNamedAfterThePDF() {
        #expect(PDFPageExporter.imageFolderName(sourceURL: source) == "Quarterly Report_images")
    }
}

// MARK: - Export service

struct ExportServicePageTests {
    private let service = ExportService()

    @Test func savesSelectedPagesAsANewPDF() async throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = PageExportFixtures.makePDF(pages: 3, in: folder)
        let destination = folder.appendingPathComponent("out.pdf")

        let alert = await service.exportPages(PageExportSource(url: url, pages: [2, 0]), as: .pdf, to: destination)

        #expect(alert.isSuccess)
        #expect(alert.output == destination)
        #expect(alert.message == DesignSystem.Alerts.pagesSaved(fileName: "out.pdf"))
        let saved = try #require(PDFDocument(url: destination))
        #expect(saved.pageCount == 2)
        #expect(saved.page(at: 0)?.bounds(for: .cropBox).width == PageExportFixtures.width(ofPage: 2))
    }

    @Test func savesOnePageAsAnImage() async throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = PageExportFixtures.makePDF(pages: 3, in: folder)
        let destination = folder.appendingPathComponent("page.png")

        let alert = await service.exportPages(PageExportSource(url: url, pages: [1]), as: .png, to: destination)

        #expect(alert.isSuccess)
        #expect(alert.sharedFiles == [destination])
        let image = try PageExportFixtures.image(try Data(contentsOf: destination))
        #expect(image.width == Int((PageExportFixtures.width(ofPage: 1) * 200 / 72).rounded()))
    }

    @Test func savesEveryPageAsItsOwnImage() async throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = PageExportFixtures.makePDF(pages: 3, in: folder)
        let output = folder.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let alert = await service.exportPageImages([PageExportSource(url: url)], as: .jpeg, into: output)

        #expect(alert.isSuccess)
        #expect(alert.output == output)
        #expect(alert.message == DesignSystem.Alerts.imagesSaved(3))
        let names = try FileManager.default.contentsOfDirectory(atPath: output.path).sorted()
        #expect(names == ["report_page-1.jpg", "report_page-2.jpg", "report_page-3.jpg"])
        #expect(alert.sharedFiles.map(\.lastPathComponent) == ["report_page-1.jpg", "report_page-2.jpg", "report_page-3.jpg"])
    }

    @Test func keepsExistingFilesAndNumbersNewOnes() async throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = PageExportFixtures.makePDF(pages: 2, in: folder)
        let existing = folder.appendingPathComponent("report_page-1.png")
        try Data("keep".utf8).write(to: existing)

        let alert = await service.exportPageImages([PageExportSource(url: url)], as: .png, into: folder)

        #expect(alert.isSuccess)
        #expect(try Data(contentsOf: existing) == Data("keep".utf8))
        #expect(alert.sharedFiles.map(\.lastPathComponent) == ["report_page-1 (2).png", "report_page-2.png"])
    }

    @Test func lockedPDFFailsWithAClearMessage() async throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try PageExportFixtures.makeLockedPDF(in: folder)

        let images = await service.exportPageImages([PageExportSource(url: url)], as: .png, into: folder)
        let pdf = await service.exportPages(PageExportSource(url: url), as: .pdf, to: folder.appendingPathComponent("out.pdf"))

        let message = DesignSystem.Alerts.pageExportFailed(.locked(url))
        #expect(images == ExportAlert(message: message, isSuccess: false))
        #expect(pdf == ExportAlert(message: message, isSuccess: false))
        #expect(message.contains("locked.pdf"))
    }

    @Test func skipsUnreadablePDFsAndSavesTheRest() async throws {
        let folder = try PageExportFixtures.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = PageExportFixtures.makePDF(pages: 1, in: folder)
        let locked = try PageExportFixtures.makeLockedPDF(in: folder)
        let output = folder.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let alert = await service.exportPageImages(
            [PageExportSource(url: locked), PageExportSource(url: url)],
            as: .png,
            into: output
        )

        #expect(alert.isSuccess)
        #expect(alert.sharedFiles.map(\.lastPathComponent) == ["report_page-1.png"])
        #expect(alert.message == DesignSystem.Alerts.message(DesignSystem.Alerts.imagesSaved(1), skipped: [locked]))
    }
}

// MARK: - Strings

struct PageExportStringsTests {
    @Test func countsUseTheCatalogPlurals() {
        #expect(DesignSystem.Alerts.imagesSaved(1) == "Saved 1 image")
        #expect(DesignSystem.Alerts.imagesSaved(3) == "Saved 3 images")
        #expect(DesignSystem.Pages.exportScope(selectedCount: 0) == "All Pages")
        #expect(DesignSystem.Pages.exportScope(selectedCount: 1) == "1 Selected Page")
        #expect(DesignSystem.Pages.exportScope(selectedCount: 4) == "4 Selected Pages")
        #expect(DesignSystem.Pages.exportDetail(.pdf, count: 1) == "One new PDF with 1 page")
        #expect(DesignSystem.Pages.exportDetail(.png, count: 2) == "2 PNG images, sharp text")
        #expect(DesignSystem.Pages.exportDetail(.jpeg, count: 1) == "1 JPEG image, smaller files")
        #expect(DesignSystem.Actions.detail(.exportPNG, count: 1, selection: true)
            == "Save each page of 1 selected PDF as a sharp PNG image")
    }

    @Test func errorsNameTheFile() {
        let url = URL(fileURLWithPath: "/tmp/Tax Return.pdf")
        #expect(DesignSystem.Alerts.pageExportFailed(.locked(url))
            == "“Tax Return.pdf” is protected with a password. Remove the password in another app, then try again.")
        #expect(DesignSystem.Alerts.pageExportFailed(.renderFailed(url, page: 2))
            == "Beaver couldn’t turn page 3 of “Tax Return.pdf” into an image.")
    }

    @Test func tooltipsNameTheExportAndItsShortcut() {
        #expect(DesignSystem.Help.exportPages(.pdf, count: 2) == "Export as PDF… (⌘E)\nOne new PDF with 2 pages")
        #expect(DesignSystem.Help.action(.exportJPEG, .unavailable(.needsPDFForImages(selection: false)))
            == "Export as JPEG (⌥⇧⌘E)\nAdd a PDF to save its pages as images")
    }
}
