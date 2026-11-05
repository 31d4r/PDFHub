import BeaverCore
import Testing
@testable import Beaver

/// Remove All asks first, then can still be undone.
@MainActor
struct RemoveAllTests {
    private func makeReactor() -> BeaverReactor {
        BeaverReactor(
            saveLocationProvider: MockSaveLocationProvider(),
            imageService: MockImageService()
        )
    }

    @Test func removeAllWaitsForConfirmation() async {
        let reactor = makeReactor()
        await reactor.action(.addFiles([TestFixtures.samplePDF]))

        await reactor.action(.requestRemoveAll)
        #expect(reactor.state.isConfirmingRemoveAll)
        #expect(reactor.state.items.count == 1)
        #expect(!reactor.state.canEdit)

        await reactor.action(.confirmRemoveAll)
        #expect(!reactor.state.isConfirmingRemoveAll)
        #expect(reactor.state.isEmpty)
    }

    /// The dialog clears its flag through its binding before the button's async action runs.
    @Test func confirmStillRemovesAfterDialogDismissal() async {
        let reactor = makeReactor()
        await reactor.action(.addFiles([TestFixtures.samplePDF]))

        await reactor.action(.requestRemoveAll)
        reactor.action(.didCancelRemoveAll)
        await reactor.action(.confirmRemoveAll)

        #expect(reactor.state.isEmpty)
    }

    @Test func removeAllCanBeUndone() async {
        let reactor = makeReactor()
        await reactor.action(.addFiles([TestFixtures.samplePDF, TestFixtures.sample2PDF]))
        let before = reactor.state.items

        await reactor.action(.requestRemoveAll)
        await reactor.action(.confirmRemoveAll)
        #expect(reactor.state.history.undoLabel == .removeAll)

        reactor.action(.undo)
        #expect(reactor.state.items == before)
    }

    @Test func mentionsRotationsOnlyWhenThereAreSome() async {
        let reactor = makeReactor()
        await reactor.action(.addFiles([TestFixtures.samplePDF]))
        #expect(!reactor.state.hasDiscardableRotations)

        let rotated = reactor.state.pdfs.map { pdf in
            var pdf = pdf
            pdf.rotationAngle = .ninety
            return pdf
        }
        reactor.action(.setPDFs(rotated))
        #expect(reactor.state.hasDiscardableRotations)
    }

    @Test func cancelKeepsFiles() async {
        let reactor = makeReactor()
        await reactor.action(.addFiles([TestFixtures.samplePDF]))

        await reactor.action(.requestRemoveAll)
        reactor.action(.didCancelRemoveAll)

        #expect(!reactor.state.isConfirmingRemoveAll)
        #expect(reactor.state.items.count == 1)
    }

    @Test func removeAllOnEmptyListDoesNothing() async {
        let reactor = makeReactor()
        await reactor.action(.requestRemoveAll)
        #expect(!reactor.state.isConfirmingRemoveAll)
    }
}
