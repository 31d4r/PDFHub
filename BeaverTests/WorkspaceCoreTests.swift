import BeaverCore
import CoreGraphics
import Foundation
import PDFKit
import Testing
@testable import Beaver

struct ItemSelectionTests {
    private let order = ["a", "b", "c", "d", "e"]

    @Test func clickSelectsOnlyThatItem() {
        var selection = ItemSelection<String>()
        selection.click("b")
        selection.click("d")
        #expect(selection.ids == ["d"])
        #expect(selection.anchor == "d")
        #expect(selection.focus == "d")
    }

    @Test func commandClickTogglesAndKeepsTheRest() {
        var selection = ItemSelection<String>()
        selection.click("a")
        selection.commandClick("c")
        #expect(selection.ids == ["a", "c"])
        selection.commandClick("a")
        #expect(selection.ids == ["c"])
    }

    @Test func shiftClickSelectsRangeInListOrder() {
        var selection = ItemSelection<String>()
        selection.click("d")
        selection.shiftClick("b", in: order)
        #expect(selection.ids == ["b", "c", "d"])
        // A new ⇧-click replaces the range from the same anchor.
        selection.shiftClick("e", in: order)
        #expect(selection.ids == ["d", "e"])
    }

    @Test func shiftClickKeepsItemsSelectedBeforeTheAnchor() {
        var selection = ItemSelection<String>()
        selection.click("a")
        selection.commandClick("c")
        selection.shiftClick("e", in: order)
        #expect(selection.ids == ["a", "c", "d", "e"])
    }

    @Test func shiftClickWithoutAnchorActsLikeClick() {
        var selection = ItemSelection<String>()
        selection.shiftClick("c", in: order)
        #expect(selection.ids == ["c"])
    }

    @Test func selectAllAndClear() {
        var selection = ItemSelection<String>()
        selection.selectAll(order)
        #expect(selection.count == 5)
        #expect(selection.focus == "a")
        selection.clear()
        #expect(selection.isEmpty)
        #expect(selection.anchor == nil)
    }

    @Test func pruneForgetsRemovedItems() {
        var selection = ItemSelection<String>()
        selection.click("b")
        selection.commandClick("c")
        selection.prune(keeping: ["a", "b", "d"])
        #expect(selection.ids == ["b"])
        #expect(selection.focus == nil)
        #expect(selection.anchor == nil)
    }

    @Test func stepMovesFocusAndClamps() {
        var selection = ItemSelection<String>()
        selection.step(by: 1, in: order, extending: false)
        #expect(selection.ids == ["a"])
        selection.step(by: 3, in: order, extending: false)
        #expect(selection.ids == ["d"])
        selection.step(by: 10, in: order, extending: false)
        #expect(selection.ids == ["e"])
        selection.step(by: -1, in: order, extending: true)
        #expect(selection.ids == ["d", "e"])
    }

    @Test func stepUpWithoutFocusStartsAtTheEnd() {
        var selection = ItemSelection<String>()
        selection.step(by: -1, in: order, extending: false)
        #expect(selection.ids == ["e"])
    }

    @Test func selectionFollowsIdsAcrossReorder() {
        var selection = ItemSelection<String>()
        selection.click("b")
        selection.shiftClick("c", in: ["c", "a", "b"])
        #expect(selection.ids == ["c", "a", "b"])
    }
}

struct GridLayoutTests {
    @Test(arguments: [
        (CGFloat(0), 1),
        (100, 1),
        (200, 1),
        (416, 2),
        (632, 3),
        (2000, 9)
    ])
    func columnCount(width: CGFloat, expected: Int) {
        #expect(GridLayout.columnCount(width: width, minimum: 200, spacing: 16) == expected)
    }

    @Test func clampedSizeRoundsToStepAndRange() {
        #expect(GridLayout.clampedSize(173, step: 20, in: 120...320) == 180)
        #expect(GridLayout.clampedSize(40, step: 20, in: 120...320) == 120)
        #expect(GridLayout.clampedSize(999, step: 20, in: 120...320) == 320)
        #expect(GridLayout.clampedSize(155, in: 120...320) == 155)
    }
}

struct ShortestTurnTests {
    @Test(arguments: [
        (RotationAngle.zero, RotationAngle.ninety, 90),
        (.ninety, .zero, -90),
        (.twoSeventy, .zero, 90),
        (.zero, .twoSeventy, -90),
        (.zero, .oneEighty, 180),
        (.oneEighty, .oneEighty, 0)
    ])
    func shortestTurn(from: RotationAngle, to: RotationAngle, expected: Int) {
        #expect(from.shortestTurn(to: to) == expected)
    }
}

struct WorkspaceItemTests {
    private func image(_ name: String) -> ImageItem {
        ImageItem(url: URL(fileURLWithPath: "/tmp/\(name).png"), thumbnail: TestImages.solid(width: 4, height: 2))
    }

    @Test func exposesKindNameAndSource() {
        let pdf = PDFItem(url: URL(fileURLWithPath: "/tmp/a.pdf"), rotationAngle: .ninety, pageRotations: [1: .oneEighty])
        let item = WorkspaceItem.pdf(pdf)
        #expect(item.kind == .pdf)
        #expect(item.name == "a.pdf")
        #expect(item.isRotated)
        #expect(item.exportSource == .pdf(pdf.url, pdf.rotation))
        #expect(item.pdf == pdf)
        #expect(item.image == nil)
    }

    @Test func rotatesEitherKind() {
        var pdf = WorkspaceItem.pdf(PDFItem(url: URL(fileURLWithPath: "/tmp/a.pdf")))
        var picture = WorkspaceItem.image(image("b"))
        pdf.rotate(.right)
        picture.rotate(.left)
        #expect(pdf.rotationAngle == .ninety)
        #expect(picture.rotationAngle == .twoSeventy)
        #expect(picture.exportSource == .image(URL(fileURLWithPath: "/tmp/b.png"), .twoSeventy))
        // The preview follows the turn.
        #expect(picture.image?.preview.width == 2)
    }

    @Test func targetsAreTheSelectionInListOrderOrEverything() {
        let items: [WorkspaceItem] = [
            .pdf(PDFItem(url: URL(fileURLWithPath: "/tmp/a.pdf"))),
            .image(image("b")),
            .pdf(PDFItem(url: URL(fileURLWithPath: "/tmp/c.pdf")))
        ]
        #expect(items.targets(selection: []) == items)
        #expect(items.targets(selection: [items[2].id, items[0].id]) == [items[0], items[2]])
        // A stale selection falls back to everything rather than nothing.
        #expect(items.targets(selection: [UUID()]) == items)
        #expect(items.pdfs.count == 2)
        #expect(items.images.count == 1)
    }
}

struct DocumentComposerTests {
    private let composer = DocumentComposer()

    private func pageCount(_ url: URL) -> Int {
        PDFDocument(url: url)?.pageCount ?? 0
    }

    @Test func combinesPDFsAndImagesInOrder() throws {
        let result = composer.combine([
            .image(TestFixtures.samplePNG, .ninety),
            .pdf(TestFixtures.samplePDF, PDFRotation(file: .oneEighty)),
            .pdf(TestFixtures.sample2PDF, .none)
        ])
        let document = try #require(result.document)
        #expect(result.skippedURLs.isEmpty)
        #expect(document.pageCount == 1 + pageCount(TestFixtures.samplePDF) + pageCount(TestFixtures.sample2PDF))
        let firstPDFPage = try #require(document.page(at: 1))
        #expect(firstPDFPage.rotation == 180)
    }

    @Test func skipsUnreadableSources() {
        let missing = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID()).pdf")
        let result = composer.combine([.pdf(missing, .none), .image(missing, .zero)])
        #expect(result.document == nil)
        #expect(result.skippedURLs == [missing, missing])
    }

    @Test func splitsPDFPagesAndImagesIntoSinglePages() {
        let result = composer.split([
            .pdf(TestFixtures.samplePDF, .none),
            .image(TestFixtures.samplePNG, .zero)
        ])
        let pdfPages = pageCount(TestFixtures.samplePDF)
        #expect(result.pages.count == pdfPages + 1)
        #expect(result.pages.first?.fileName == "sample_page-1.pdf")
        #expect(result.pages.last?.fileName == "sample.pdf")
        #expect(result.pages.allSatisfy { $0.document.pageCount == 1 })
    }

    @Test func stopsWhenCancelled() async {
        let composer = composer
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return composer.combine([.pdf(TestFixtures.samplePDF, .none)]).document == nil
        }
        let isEmpty = await task.value
        #expect(isEmpty)
    }
}

struct UndoHistorySnapshotsTests {
    @Test func listsUndoThenRedoSnapshots() {
        var history = UndoHistory<Int, String>()
        history.record(1, label: "a")
        history.record(2, label: "b")
        _ = history.undo(current: 3)
        #expect(history.snapshots == [1, 3])
    }
}

struct ImagePixelSizeTests {
    @Test func readsPixelSize() throws {
        let size = try #require(ImageService().pixelSize(for: TestFixtures.samplePNG))
        let image = try #require(ImageService().thumbnail(for: TestFixtures.samplePNG, maxPixelSize: 10_000))
        #expect(size == CGSize(width: image.width, height: image.height))
    }

    @Test func unreadableImageHasNoSize() {
        #expect(ImageService().pixelSize(for: URL(fileURLWithPath: "/tmp/missing-\(UUID()).png")) == nil)
    }
}
