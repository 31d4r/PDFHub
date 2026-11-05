import BeaverCore
import Foundation
import ImageIO
import PDFKit
import Testing
import UniformTypeIdentifiers
@testable import Beaver

struct MoveDirectionTests {
    @Test(arguments: [
        (MoveDirection.toStart, 2, 0),
        (.previous, 2, 1),
        (.next, 1, 2),
        (.toEnd, 0, 3),
    ])
    func destinationInsideList(direction: MoveDirection, index: Int, expected: Int) {
        #expect(direction.destination(from: index, count: 4) == expected)
    }

    @Test func noDestinationAtTheEnds() {
        #expect(MoveDirection.toStart.destination(from: 0, count: 3) == nil)
        #expect(MoveDirection.previous.destination(from: 0, count: 3) == nil)
        #expect(MoveDirection.next.destination(from: 2, count: 3) == nil)
        #expect(MoveDirection.toEnd.destination(from: 2, count: 3) == nil)
    }

    @Test func noDestinationOutOfRange() {
        for direction in MoveDirection.allCases {
            #expect(direction.destination(from: -1, count: 3) == nil)
            #expect(direction.destination(from: 3, count: 3) == nil)
            #expect(direction.destination(from: 0, count: 1) == nil)
        }
    }
}

struct ArrayMoveTests {
    private struct Item: Identifiable, Equatable {
        let id: Int
    }

    private let items = [Item(id: 1), Item(id: 2), Item(id: 3)]

    @Test func firstToLast() {
        var list = items
        let moved = list.move(id: 1, to: 2)
        #expect(moved)
        #expect(list.map(\.id) == [2, 3, 1])
    }

    @Test func lastToFirst() {
        var list = items
        let moved = list.move(id: 3, to: 0)
        #expect(moved)
        #expect(list.map(\.id) == [3, 1, 2])
    }

    @Test func sameIndexIsNoOp() {
        var list = items
        let moved = list.move(id: 2, to: 1)
        #expect(!moved)
        #expect(list == items)
    }

    @Test func outOfRangeAndUnknownIdAreIgnored() {
        var list = items
        let pastEnd = list.move(id: 1, to: 3)
        let negative = list.move(id: 1, to: -1)
        let unknown = list.move(id: 9, to: 0)
        #expect(!pastEnd)
        #expect(!negative)
        #expect(!unknown)
        #expect(list == items)
    }
}

@MainActor
struct ReactorReorderTests {
    private let destination = URL(fileURLWithPath: "/tmp/beaver-tests/reordered.pdf")
    private let urls = (1...3).map { URL(fileURLWithPath: "/tmp/beaver-tests/\($0).png") }

    private func makeReactor(
        panels: MockSaveLocationProvider = MockSaveLocationProvider(),
        export: any ExportServiceProtocol = MockExportService(),
        images: MockImageService = MockImageService()
    ) -> BeaverReactor {
        BeaverReactor(saveLocationProvider: panels, imageService: images, exportService: export)
    }

    private func makeImageReactor(
        urls: [URL],
        panels: MockSaveLocationProvider = MockSaveLocationProvider(),
        export: any ExportServiceProtocol = MockExportService()
    ) async -> BeaverReactor {
        let images = MockImageService()
        for url in urls {
            images.thumbnailsByURL[url] = TestImages.solid(width: 4, height: 4)
        }
        let reactor = makeReactor(panels: panels, export: export, images: images)
        await reactor.action(.addImages(urls))
        return reactor
    }

    private func pdfReactor(export: any ExportServiceProtocol = MockExportService(), panels: MockSaveLocationProvider = MockSaveLocationProvider()) -> BeaverReactor {
        let reactor = makeReactor(panels: panels, export: export)
        reactor.action(.didUserSelectPDF([
            PDFItem(url: TestFixtures.samplePDF),
            PDFItem(url: TestFixtures.sample2PDF),
            PDFItem(url: URL(fileURLWithPath: "/tmp/beaver-tests/third.pdf")),
        ]))
        return reactor
    }

    // MARK: - PDFs

    @Test func pdfFirstToLast() {
        let reactor = pdfReactor()
        let before = reactor.state.selectedPDFs
        reactor.action(.movePDF(id: before[0].id, to: 2))
        #expect(reactor.state.selectedPDFs.map(\.id) == [before[1].id, before[2].id, before[0].id])
    }

    @Test func pdfLastToFirst() {
        let reactor = pdfReactor()
        let before = reactor.state.selectedPDFs
        reactor.action(.movePDF(id: before[2].id, to: 0))
        #expect(reactor.state.selectedPDFs.map(\.id) == [before[2].id, before[0].id, before[1].id])
    }

    @Test func pdfNoOpAndOutOfRange() {
        let reactor = pdfReactor()
        let before = reactor.state.selectedPDFs
        reactor.action(.movePDF(id: before[1].id, to: 1))
        reactor.action(.movePDF(id: before[1].id, to: 3))
        reactor.action(.movePDF(id: before[1].id, to: -1))
        reactor.action(.movePDF(id: UUID(), to: 0))
        #expect(reactor.state.selectedPDFs == before)
    }

    @Test func rotationStaysWithMovedPDF() {
        let reactor = pdfReactor()
        var pdfs = reactor.state.selectedPDFs
        pdfs[0].rotationAngle = .ninety
        reactor.action(.didUserSelectPDF(pdfs))

        reactor.action(.movePDF(id: pdfs[0].id, to: 2))

        let moved = reactor.state.selectedPDFs
        #expect(moved[2].id == pdfs[0].id)
        #expect(moved[2].rotationAngle == .ninety)
        #expect(moved[0].rotationAngle == .zero)
        #expect(moved[1].rotationAngle == .zero)
    }

    @Test func mergeFollowsNewOrderWithRotations() async {
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let export = MockExportService()
        let reactor = makeReactor(panels: panels, export: export)
        reactor.action(.didUserSelectPDF([
            PDFItem(url: TestFixtures.samplePDF),
            PDFItem(url: TestFixtures.sample2PDF, rotationAngle: .oneEighty),
        ]))
        let second = reactor.state.selectedPDFs[1]

        reactor.action(.movePDF(id: second.id, to: 0))
        await reactor.action(.mergePDF(reactor.state.selectedPDFs.map(\.url)))

        #expect(export.calls == [.merge(
            urls: [TestFixtures.sample2PDF, TestFixtures.samplePDF],
            rotationAngles: [TestFixtures.sample2PDF: 180, TestFixtures.samplePDF: 0],
            destination: destination
        )])
    }

    @Test func mergedFilePageOrderFollowsNewOrder() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BeaverReorderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("merged.pdf")
        let panels = MockSaveLocationProvider()
        panels.saveURL = output
        let reactor = makeReactor(panels: panels, export: ExportService())
        reactor.action(.didUserSelectPDF([
            PDFItem(url: TestFixtures.samplePDF),
            PDFItem(url: TestFixtures.sample2PDF, rotationAngle: .ninety),
        ]))
        reactor.action(.movePDF(id: reactor.state.selectedPDFs[1].id, to: 0))

        await reactor.action(.mergePDF(reactor.state.selectedPDFs.map(\.url)))

        let first = try #require(PDFDocument(url: TestFixtures.sample2PDF))
        let second = try #require(PDFDocument(url: TestFixtures.samplePDF))
        let merged = try #require(PDFDocument(url: output))
        #expect(merged.pageCount == first.pageCount + second.pageCount)
        for index in 0..<merged.pageCount {
            let source = index < first.pageCount
                ? first.page(at: index)
                : second.page(at: index - first.pageCount)
            let page = merged.page(at: index)
            #expect(page?.bounds(for: .mediaBox) == source?.bounds(for: .mediaBox))
            #expect(page?.string == source?.string)
            let expectedRotation = index < first.pageCount ? 90 : 0
            #expect(((page?.rotation ?? 0) - (source?.rotation ?? 0) + 360) % 360 == expectedRotation)
        }
    }

    // MARK: - Images

    @Test func imageFirstToLast() async {
        let reactor = await makeImageReactor(urls: urls)
        let first = reactor.state.selectedImages[0]
        reactor.action(.moveImage(id: first.id, to: 2))
        #expect(reactor.state.selectedImages.map(\.url) == [urls[1], urls[2], urls[0]])
    }

    @Test func imageLastToFirst() async {
        let reactor = await makeImageReactor(urls: urls)
        let last = reactor.state.selectedImages[2]
        reactor.action(.moveImage(id: last.id, to: 0))
        #expect(reactor.state.selectedImages.map(\.url) == [urls[2], urls[0], urls[1]])
    }

    @Test func imageNoOpAndOutOfRange() async {
        let reactor = await makeImageReactor(urls: urls)
        let middle = reactor.state.selectedImages[1]
        reactor.action(.moveImage(id: middle.id, to: 1))
        reactor.action(.moveImage(id: middle.id, to: 5))
        reactor.action(.moveImage(id: middle.id, to: -1))
        reactor.action(.moveImage(id: UUID(), to: 0))
        #expect(reactor.state.selectedImages.map(\.url) == urls)
    }

    @Test func convertFollowsNewOrder() async {
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let export = MockExportService()
        let reactor = await makeImageReactor(urls: urls, panels: panels, export: export)

        reactor.action(.moveImage(id: reactor.state.selectedImages[2].id, to: 0))
        await reactor.action(.convertImagesToPDF)

        #expect(export.calls == [.convert(urls: [urls[2], urls[0], urls[1]], destination: destination)])
    }

    @Test func convertedFilePageOrderFollowsNewOrder() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BeaverReorderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let wide = directory.appendingPathComponent("wide.png")
        let tall = directory.appendingPathComponent("tall.png")
        try writePNG(TestImages.solid(width: 80, height: 40), to: wide)
        try writePNG(TestImages.solid(width: 40, height: 80), to: tall)
        let output = directory.appendingPathComponent("converted.pdf")
        let panels = MockSaveLocationProvider()
        panels.saveURL = output
        let reactor = await makeImageReactor(urls: [wide, tall], panels: panels, export: ExportService())

        reactor.action(.moveImage(id: reactor.state.selectedImages[1].id, to: 0))
        await reactor.action(.convertImagesToPDF)

        let document = try #require(PDFDocument(url: output))
        #expect(document.pageCount == 2)
        let firstPage = try #require(document.page(at: 0)?.bounds(for: .mediaBox))
        let secondPage = try #require(document.page(at: 1)?.bounds(for: .mediaBox))
        #expect(firstPage.height > firstPage.width)
        #expect(secondPage.width > secondPage.height)
    }

    // MARK: - Activity

    @Test func movesAreIgnoredWhileExporting() async {
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let export = MockExportService(isGated: true)
        let reactor = await makeImageReactor(urls: urls, panels: panels, export: export)
        reactor.action(.didUserSelectPDF([PDFItem(url: TestFixtures.samplePDF), PDFItem(url: TestFixtures.sample2PDF)]))
        let pdfsBefore = reactor.state.selectedPDFs

        let running = Task { await reactor.action(.convertImagesToPDF) }
        while reactor.state.activity == nil {
            await Task.yield()
        }

        reactor.action(.moveImage(id: reactor.state.selectedImages[0].id, to: 2))
        reactor.action(.movePDF(id: pdfsBefore[0].id, to: 1))
        #expect(reactor.state.selectedImages.map(\.url) == urls)
        #expect(reactor.state.selectedPDFs == pdfsBefore)

        export.release()
        await running.value
        #expect(reactor.state.activity == nil)
        #expect(export.calls == [.convert(urls: urls, destination: destination)])
    }

    // MARK: - Drag payload

    @Test func dragTypeIsDeclaredByTheApp() {
        #expect(UTType.beaverCard.identifier == "com.eldartutnjic.Beaver.card")
        #expect(UTType.beaverCard.isDeclared)
        #expect(!UTType.beaverCard.conforms(to: .fileURL))
    }

    private func writePNG(_ image: CGImage, to url: URL) throws {
        let destination = try #require(
            CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }
}
