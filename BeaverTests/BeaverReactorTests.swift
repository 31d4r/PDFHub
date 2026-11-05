import BeaverCore
import Foundation
import Testing
@testable import Beaver

/// The unified workspace: adding, selecting, removing with undo, and Quick Look.
@MainActor
struct BeaverReactorTests {
    private let secondPNG = URL(fileURLWithPath: "/tmp/second.png")

    private func makeReactor() -> BeaverReactor {
        let images = MockImageService()
        images.thumbnailsByURL[TestFixtures.samplePNG] = TestImages.solid(width: 10, height: 10)
        images.thumbnailsByURL[secondPNG] = TestImages.solid(width: 12, height: 12)
        return BeaverReactor(saveLocationProvider: MockSaveLocationProvider(), imageService: images)
    }

    /// A PDF, an image, a PDF and an image, in that order.
    private func makeMixedReactor() async -> BeaverReactor {
        let reactor = makeReactor()
        await reactor.action(.addFiles([TestFixtures.samplePDF, TestFixtures.samplePNG, TestFixtures.sample2PDF, secondPNG]))
        return reactor
    }

    @Test func addKeepsDropOrderAcrossKindsAndDeduplicates() async {
        let reactor = makeReactor()

        await reactor.action(.addFiles([TestFixtures.samplePDF, TestFixtures.samplePNG, TestFixtures.samplePDF]))
        await reactor.action(.addFiles([TestFixtures.samplePNG]))

        #expect(reactor.state.items.map(\.url) == [TestFixtures.samplePDF, TestFixtures.samplePNG])
        #expect(reactor.state.items.map(\.kind) == [.pdf, .image])
        #expect(reactor.state.pdfs.count == 1)
        #expect(reactor.state.images.count == 1)
    }

    @Test func addingRecordsUndo() async {
        let reactor = makeReactor()
        await reactor.action(.addFiles([TestFixtures.samplePDF]))
        #expect(reactor.state.history.undoLabel == .add)

        reactor.action(.undo)
        #expect(reactor.state.isEmpty)

        reactor.action(.redo)
        #expect(reactor.state.items.map(\.url) == [TestFixtures.samplePDF])
    }

    @Test func clickCommandClickAndShiftClickSelect() async {
        let reactor = await makeMixedReactor()
        let ids = reactor.state.items.map(\.id)

        reactor.action(.select(ids[1], .none))
        #expect(reactor.state.selection.ids == [ids[1]])

        reactor.action(.select(ids[3], .command))
        #expect(reactor.state.selection.ids == [ids[1], ids[3]])

        reactor.action(.select(ids[0], .none))
        reactor.action(.select(ids[2], .shift))
        #expect(reactor.state.selection.ids == Set(ids[0...2]))

        reactor.action(.selectAll)
        #expect(reactor.state.selection.count == 4)

        reactor.action(.deselectAll)
        #expect(!reactor.state.hasSelection)
    }

    @Test func arrowKeysMoveAndExtendTheSelection() async {
        let reactor = await makeMixedReactor()
        let ids = reactor.state.items.map(\.id)
        reactor.action(.select(ids[0], .none))

        reactor.action(.moveFocus(offset: 1, extending: false))
        #expect(reactor.state.selection.ids == [ids[1]])

        reactor.action(.moveFocus(offset: 2, extending: true))
        #expect(reactor.state.selection.ids == Set(ids[1...3]))
    }

    @Test func actionsTargetTheSelectionOrEverything() async {
        let reactor = await makeMixedReactor()
        let ids = reactor.state.items.map(\.id)
        #expect(reactor.state.targets.count == 4)
        #expect(reactor.state.exportKind == .mixed)

        reactor.action(.select(ids[0], .none))
        reactor.action(.select(ids[2], .command))

        #expect(reactor.state.targets.map(\.id) == [ids[0], ids[2]])
        #expect(reactor.state.exportKind == .pdfs)
    }

    @Test func rotateAllTurnsOnlyTheSelection() async {
        let reactor = await makeMixedReactor()
        let ids = reactor.state.items.map(\.id)
        reactor.action(.select(ids[1], .none))

        reactor.action(.rotateAll(.right))

        #expect(reactor.state.items.map(\.rotationAngle) == [.zero, .ninety, .zero, .zero])
        #expect(reactor.state.history.undoLabel == .rotate)

        reactor.action(.deselectAll)
        reactor.action(.rotateAll(.left))
        #expect(reactor.state.items.map(\.rotationAngle) == [.twoSeventy, .zero, .twoSeventy, .twoSeventy])
        #expect(reactor.state.history.undoLabel == .rotateAll)
    }

    @Test func removeTakesTheSelectionAndUndoBringsItBack() async {
        let reactor = await makeMixedReactor()
        let before = reactor.state.items
        let ids = before.map(\.id)
        reactor.action(.select(ids[1], .none))
        reactor.action(.select(ids[2], .command))

        reactor.action(.remove(reactor.state.selection.ids))

        #expect(reactor.state.items.map(\.id) == [ids[0], ids[3]])
        #expect(!reactor.state.hasSelection)
        #expect(reactor.state.history.undoLabel == .remove)

        reactor.action(.undo)
        #expect(reactor.state.items == before)
    }

    @Test func removingNothingRecordsNothing() async {
        let reactor = await makeMixedReactor()
        let label = reactor.state.history.undoLabel

        reactor.action(.remove([UUID()]))

        #expect(reactor.state.items.count == 4)
        #expect(reactor.state.history.undoLabel == label)
    }

    @Test func openShowsPagesForPDFsAndQuickLookForImages() async {
        let reactor = await makeMixedReactor()
        let ids = reactor.state.items.map(\.id)

        reactor.action(.open(id: ids[1]))
        #expect(reactor.state.quickLookURL == TestFixtures.samplePNG)
        #expect(!reactor.state.isPagesPresented)

        reactor.action(.didChangeQuickLook(nil))
        reactor.action(.open(id: ids[0]))
        #expect(reactor.state.pagesPDF?.id == ids[0])
        #expect(!reactor.state.canEdit)

        reactor.action(.didChangePagesPresented(false))
        #expect(reactor.state.pagesPDFID == nil)
    }

    @Test func spaceTogglesQuickLookOnTheSelection() async {
        let reactor = await makeMixedReactor()
        let ids = reactor.state.items.map(\.id)

        reactor.action(.toggleQuickLook)
        #expect(reactor.state.quickLookURL == TestFixtures.samplePDF)
        reactor.action(.toggleQuickLook)
        #expect(reactor.state.quickLookURL == nil)

        reactor.action(.select(ids[3], .none))
        reactor.action(.toggleQuickLook)
        #expect(reactor.state.quickLookURL == secondPNG)
    }

    @Test func removingTheQuickLookFileClosesThePreview() async {
        let reactor = await makeMixedReactor()
        let ids = reactor.state.items.map(\.id)
        reactor.action(.open(id: ids[1]))

        reactor.action(.remove([ids[1]]))

        #expect(reactor.state.quickLookURL == nil)
    }

    @Test func exportKindFollowsTheMix() async {
        let reactor = await makeMixedReactor()
        let items = reactor.state.items

        #expect(ExportKind([items[0], items[2]]) == .pdfs)
        #expect(ExportKind([items[1], items[3]]) == .images)
        #expect(ExportKind(items) == .mixed)
        #expect(ExportKind.pdfs.defaultFileName == DesignSystem.FileNames.mergedPDF)
        #expect(ExportKind.mixed.defaultFileName == DesignSystem.FileNames.combinedPDF)
    }
}
