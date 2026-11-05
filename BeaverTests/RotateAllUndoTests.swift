import BeaverCore
import Foundation
import Testing
@testable import Beaver

struct UndoHistoryTests {
    @Test func undoAndRedoWalkTheStack() {
        var history = UndoHistory<Int, String>()
        history.record(0, label: "a")
        history.record(1, label: "b")
        #expect(history.undoLabel == "b")

        let first = history.undo(current: 2)
        #expect(first == 1)
        #expect(history.redoLabel == "b")
        let second = history.undo(current: 1)
        #expect(second == 0)
        let none = history.undo(current: 0)
        #expect(none == nil)

        let redone = history.redo(current: 0)
        #expect(redone == 1)
        #expect(history.canUndo && history.canRedo)
    }

    @Test func recordingClearsRedo() {
        var history = UndoHistory<Int, String>()
        history.record(0, label: "a")
        _ = history.undo(current: 1)
        history.record(0, label: "c")
        #expect(!history.canRedo)
        #expect(history.undoEntries.count == 1)
    }

    @Test func dropsTheOldestPastTheLimit() {
        var history = UndoHistory<Int, String>(limit: 2)
        history.record(0, label: "a")
        history.record(1, label: "b")
        history.record(2, label: "c")
        #expect(history.undoEntries.map(\.snapshot) == [1, 2])
    }
}

@MainActor
struct RotateAllUndoTests {
    private let destination = URL(fileURLWithPath: "/tmp/beaver-rotate-all.pdf")
    private let imageURLs = (1...3).map { URL(fileURLWithPath: "/tmp/beaver-rotate-all-\($0).png") }

    private func makePDFReactor(export: MockExportService = MockExportService()) -> BeaverReactor {
        let panels = MockSaveLocationProvider()
        panels.saveURL = destination
        let reactor = BeaverReactor(saveLocationProvider: panels, imageService: MockImageService(), exportService: export)
        reactor.action(.setPDFs([PDFItem(url: TestFixtures.samplePDF), PDFItem(url: TestFixtures.sample2PDF)]))
        return reactor
    }

    private func makeImageReactor() async -> BeaverReactor {
        let images = MockImageService()
        for url in imageURLs {
            images.thumbnailsByURL[url] = TestImages.solid(width: 30, height: 10)
        }
        let reactor = BeaverReactor(saveLocationProvider: MockSaveLocationProvider(), imageService: images)
        await reactor.action(.addFiles(imageURLs))
        return reactor
    }

    private func pdfAngles(_ reactor: BeaverReactor) -> [RotationAngle] {
        reactor.state.pdfs.map(\.rotationAngle)
    }

    private func imageAngles(_ reactor: BeaverReactor) -> [RotationAngle] {
        reactor.state.images.map(\.rotationAngle)
    }

    // MARK: - Rotate all

    @Test func rotateAllTurnsEveryPDF() {
        let reactor = makePDFReactor()
        reactor.action(.rotate(id: reactor.state.pdfs[0].id, direction: .right))

        reactor.action(.rotateAll(.right))
        #expect(pdfAngles(reactor) == [.oneEighty, .ninety])

        reactor.action(.rotateAll(.left))
        reactor.action(.rotateAll(.left))
        #expect(pdfAngles(reactor) == [.zero, .twoSeventy])
    }

    @Test func rotateAllTurnsEveryImageAndItsPreview() async {
        let reactor = await makeImageReactor()

        reactor.action(.rotateAll(.left))

        #expect(imageAngles(reactor) == [.twoSeventy, .twoSeventy, .twoSeventy])
        #expect(reactor.state.images.allSatisfy { $0.preview.width == 10 && $0.preview.height == 30 })
    }

    @Test func rotateAllTurnsEveryKindWhenNothingIsSelected() async {
        let reactor = await makeImageReactor()
        reactor.action(.setPDFs([PDFItem(url: TestFixtures.samplePDF)]))

        reactor.action(.rotateAll(.right))

        #expect(pdfAngles(reactor) == [.ninety])
        #expect(imageAngles(reactor) == [.ninety, .ninety, .ninety])
    }

    @Test func rotateAllIsUnavailableWithNothingToTurn() {
        let reactor = BeaverReactor(saveLocationProvider: MockSaveLocationProvider(), imageService: MockImageService())
        #expect(!reactor.state.canRotateAll)
        reactor.action(.rotateAll(.right))
        #expect(!reactor.state.history.canUndo)
    }

    // MARK: - Undo

    @Test func undoAndRedoRotateAll() {
        let reactor = makePDFReactor()
        reactor.action(.rotateAll(.right))
        #expect(reactor.state.history.undoLabel == .rotateAll)

        reactor.action(.undo)
        #expect(pdfAngles(reactor) == [.zero, .zero])
        #expect(reactor.state.history.redoLabel == .rotateAll)

        reactor.action(.redo)
        #expect(pdfAngles(reactor) == [.ninety, .ninety])
    }

    @Test func everyRotationIsUndoableInOrder() async {
        let reactor = await makeImageReactor()
        let first = reactor.state.images[0].id
        reactor.action(.rotate(id: first, direction: .right))
        reactor.action(.rotateAll(.right))
        reactor.action(.rotate(id: first, direction: .left))
        #expect(imageAngles(reactor) == [.ninety, .ninety, .ninety])

        reactor.action(.undo)
        #expect(imageAngles(reactor) == [.oneEighty, .ninety, .ninety])
        reactor.action(.undo)
        #expect(imageAngles(reactor) == [.ninety, .zero, .zero])
        reactor.action(.undo)
        #expect(imageAngles(reactor) == [.zero, .zero, .zero])
        #expect(reactor.state.images[0].preview.width == 30)
        #expect(reactor.state.history.undoLabel == .add)

        reactor.action(.redo)
        reactor.action(.redo)
        #expect(imageAngles(reactor) == [.oneEighty, .ninety, .ninety])
    }

    @Test func undoRevertsTheMoveBeforeTheRotation() {
        let reactor = makePDFReactor()
        let second = reactor.state.pdfs[1]
        reactor.action(.rotateAll(.right))
        reactor.action(.move(id: second.id, to: 0))
        #expect(reactor.state.history.undoLabel == .move)

        reactor.action(.undo)
        #expect(reactor.state.pdfs.map(\.url) == [TestFixtures.samplePDF, TestFixtures.sample2PDF])
        #expect(pdfAngles(reactor) == [.ninety, .ninety])

        reactor.action(.undo)
        #expect(pdfAngles(reactor) == [.zero, .zero])
    }

    @Test func undoBringsBackARemovedCardWithItsRotation() async {
        let reactor = makePDFReactor()
        let first = reactor.state.pdfs[0].id
        let second = reactor.state.pdfs[1].id
        reactor.action(.rotate(id: second, direction: .right))
        reactor.action(.rotate(id: first, direction: .right))
        reactor.action(.remove([first]))
        #expect(reactor.state.pdfs.map(\.id) == [second])

        reactor.action(.undo)
        #expect(reactor.state.pdfs.map(\.id) == [first, second])
        #expect(pdfAngles(reactor) == [.ninety, .ninety])

        reactor.action(.undo)
        reactor.action(.undo)
        #expect(pdfAngles(reactor) == [.zero, .zero])
    }

    @Test func newRotationClearsRedo() {
        let reactor = makePDFReactor()
        reactor.action(.rotateAll(.right))
        reactor.action(.undo)
        reactor.action(.rotate(id: reactor.state.pdfs[0].id, direction: .left))
        #expect(!reactor.state.history.canRedo)
        #expect(reactor.state.history.undoLabel == .rotate)
    }

    @Test func removeAllCanBeUndoneWithRotationsIntact() async {
        let reactor = makePDFReactor()
        reactor.action(.rotateAll(.right))
        await reactor.action(.requestRemoveAll)
        await reactor.action(.confirmRemoveAll)
        #expect(reactor.state.isEmpty)
        #expect(reactor.state.history.undoLabel == .removeAll)

        reactor.action(.undo)
        #expect(pdfAngles(reactor) == [.ninety, .ninety])
        #expect(reactor.state.history.undoLabel == .rotateAll)
    }

    // MARK: - Activity

    @Test func rotationsAndUndoAreIgnoredWhileExporting() async {
        let export = MockExportService(isGated: true)
        let reactor = makePDFReactor(export: export)
        reactor.action(.rotateAll(.right))
        let urls = reactor.state.pdfs.map(\.url)

        let running = Task { await reactor.exportOneFile() }
        while reactor.state.activity == nil {
            await Task.yield()
        }

        #expect(!reactor.state.canRotateAll)
        #expect(!reactor.state.canUndo)
        reactor.action(.rotateAll(.right))
        reactor.action(.rotate(id: reactor.state.pdfs[0].id, direction: .left))
        reactor.action(.undo)
        #expect(pdfAngles(reactor) == [.ninety, .ninety])

        export.release()
        await running.value
        #expect(reactor.state.canUndo)
        #expect(export.calls == [.merge(
            urls: urls,
            rotations: [PDFRotation(file: .ninety), PDFRotation(file: .ninety)],
            destination: destination
        )])
    }

    // MARK: - Menu titles

    @Test func menuTitlesNameTheChange() {
        #expect(DesignSystem.Commands.undo(BeaverReactor.Edit.rotateAll.title) == "Undo Rotate All")
        #expect(DesignSystem.Commands.redo(BeaverReactor.Edit.rotate.title) == "Redo Rotate")
        #expect(DesignSystem.Commands.rotateAllLeft == "Rotate All Left")
    }
}
