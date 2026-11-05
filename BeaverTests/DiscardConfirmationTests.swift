import Testing
@testable import Beaver

@MainActor
struct DiscardConfirmationTests {
    private func makeReactor() -> BeaverReactor {
        BeaverReactor(
            filePanelService: MockFilePanelService(),
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

        await reactor.action(.confirmDiscard)
        #expect(reactor.state.pendingDiscard == nil)
        #expect(reactor.state.selectedPDFs.isEmpty)
        #expect(reactor.state.screen == .menu)
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
