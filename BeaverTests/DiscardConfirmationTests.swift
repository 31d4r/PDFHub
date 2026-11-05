import BeaverCore
import Testing
@testable import Beaver

@MainActor
struct DiscardConfirmationTests {
    private func makeReactor() -> BeaverReactor {
        BeaverReactor(
            saveLocationProvider: MockSaveLocationProvider(),
            imageService: MockImageService()
        )
    }

    @Test(arguments: [BeaverReactor.DiscardRequest.goBack, .clearAll])
    func discardWaitsForConfirmation(request: BeaverReactor.DiscardRequest) async {
        let reactor = makeReactor()
        await reactor.action(.addPDFs([TestFixtures.samplePDF]))

        await reactor.action(.requestDiscard(request))
        #expect(reactor.state.pendingDiscard == request)
        #expect(reactor.state.selectedPDFs.count == 1)

        await reactor.action(.confirmDiscard(request))
        #expect(reactor.state.pendingDiscard == nil)
        #expect(reactor.state.selectedPDFs.isEmpty)
        #expect(reactor.state.screen == .menu)
    }

    /// The dialog clears `pendingDiscard` through its binding before the button's async action runs.
    @Test(arguments: [BeaverReactor.DiscardRequest.goBack, .clearAll])
    func confirmStillDiscardsAfterDialogDismissal(request: BeaverReactor.DiscardRequest) async {
        let reactor = makeReactor()
        await reactor.action(.addPDFs([TestFixtures.samplePDF]))

        await reactor.action(.requestDiscard(request))
        reactor.action(.didCancelDiscard)
        await reactor.action(.confirmDiscard(request))

        #expect(reactor.state.pendingDiscard == nil)
        #expect(reactor.state.selectedPDFs.isEmpty)
        #expect(reactor.state.screen == .menu)
    }

    @Test func mentionsRotationsOnlyWhenThereAreSome() async {
        let reactor = makeReactor()
        await reactor.action(.addPDFs([TestFixtures.samplePDF]))
        #expect(!reactor.state.hasDiscardableRotations)

        let rotated = reactor.state.selectedPDFs.map { pdf in
            var pdf = pdf
            pdf.rotationAngle = .ninety
            return pdf
        }
        reactor.action(.didUserSelectPDF(rotated))
        #expect(reactor.state.hasDiscardableRotations)
    }

    @Test func cancelKeepsFiles() async {
        let reactor = makeReactor()
        await reactor.action(.addPDFs([TestFixtures.samplePDF]))

        await reactor.action(.requestDiscard(.clearAll))
        reactor.action(.didCancelDiscard)

        #expect(reactor.state.pendingDiscard == nil)
        #expect(reactor.state.selectedPDFs.count == 1)
        #expect(reactor.state.screen == .pdfWorkflow)
    }

    @Test func discardOnMenuDoesNothing() async {
        let reactor = makeReactor()
        await reactor.action(.requestDiscard(.goBack))
        #expect(reactor.state.pendingDiscard == nil)
        #expect(reactor.state.screen == .menu)
    }
}
