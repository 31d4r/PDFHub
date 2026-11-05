import Testing
@testable import Beaver

@MainActor
struct ExportAlertStateTests {
    @Test func alertStaysUntilDismissed() async {
        let reactor = BeaverReactor(
            filePanelService: MockFilePanelService(),
            imageService: MockImageService()
        )

        await reactor.action(.showAlert(message: "Done", success: true))
        #expect(reactor.state.exportAlert == ExportAlert(message: "Done", isSuccess: true))

        reactor.action(.didDismissAlert)
        #expect(reactor.state.exportAlert == nil)
    }
}
