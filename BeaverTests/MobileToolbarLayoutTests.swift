import Testing
@testable import Beaver

/// The iOS toolbar leaves the empty workspace to its four big buttons.
@MainActor
struct MobileToolbarLayoutTests {
    private func makeReactor() -> BeaverReactor {
        BeaverReactor(
            saveLocationProvider: MockSaveLocationProvider(),
            imageService: MockImageService()
        )
    }

    @Test func anEmptyWorkspaceShowsNoToolbarControls() {
        let layout = MobileToolbarLayout(makeReactor().state)
        #expect(layout == MobileToolbarLayout(
            showsMoreMenu: false,
            showsSelect: false,
            showsAddMenu: false,
            showsActionsMenu: false
        ))
        #expect(!layout.showsBottomBar)
    }

    @Test func filesBringBackAddSelectMoreAndActions() async {
        let reactor = makeReactor()
        await reactor.action(.addFiles([TestFixtures.samplePDF]))
        let layout = MobileToolbarLayout(reactor.state)
        #expect(layout == MobileToolbarLayout(
            showsMoreMenu: true,
            showsSelect: true,
            showsAddMenu: true,
            showsActionsMenu: true
        ))
        #expect(layout.showsBottomBar)
    }

    /// Emptied by Remove All, the more menu stays for Undo, but there is still nothing to add
    /// from the toolbar or to select.
    @Test func moreStaysForUndoAfterRemovingEverything() async {
        let reactor = makeReactor()
        await reactor.action(.addFiles([TestFixtures.samplePDF]))
        await reactor.action(.requestRemoveAll)
        await reactor.action(.confirmRemoveAll)
        #expect(reactor.state.isEmpty && reactor.state.canUndo)

        let layout = MobileToolbarLayout(reactor.state)
        #expect(layout.showsMoreMenu)
        #expect(!layout.showsSelect && !layout.showsAddMenu && !layout.showsBottomBar)

        reactor.action(.undo)
        #expect(MobileToolbarLayout(reactor.state).showsAddMenu)
    }

    /// Undoing the first add empties the workspace; Redo can bring the file back.
    @Test func redoAloneKeepsTheMoreMenu() {
        var state = BeaverReactor.State()
        state.history.record([], label: .removeAll)
        _ = state.history.undo(current: [])
        #expect(state.isEmpty && !state.canUndo && state.canRedo)
        #expect(MobileToolbarLayout(state).showsMoreMenu)
        #expect(!MobileToolbarLayout(state).showsAddMenu)
    }
}
